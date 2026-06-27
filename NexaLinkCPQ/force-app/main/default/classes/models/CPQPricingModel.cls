/**
 * CPQPricingModel
 * Domain model for quote-line synchronisation and CPQ price calculation.
 * Delegates the heavy work that was previously in CPQConfiguratorController.
 */
public without sharing class CPQPricingModel {

    // ─────────────────────────────────────────────────────────────────────────
    // CLEAR + SYNC (bundles + standalones in one shot)
    // ─────────────────────────────────────────────────────────────────────────
    public static Map<String,Object> clearAndAddAllBundles(String quoteId, String bundlesJson, String standaloneJson) {
        try {
            if (String.isNotBlank(quoteId)) {
                // Committed delete before the savepoint lets CPQ's after-delete trigger
                // settle the quote state so the subsequent insert does not trigger the
                // "Changing currency on quotes with line items" validation rule.
                delete [SELECT Id FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :quoteId];
            }
            List<Object> merged = new List<Object>();
            if (String.isNotBlank(bundlesJson))    merged.addAll((List<Object>) JSON.deserializeUntyped(bundlesJson));
            if (String.isNotBlank(standaloneJson)) merged.addAll((List<Object>) JSON.deserializeUntyped(standaloneJson));
            return syncProductsToQuote(quoteId, JSON.serialize(merged));
        } catch (Exception e) {
            return new Map<String,Object>{
                'success' => false,
                'error'   => e.getMessage() + ' | line: ' + e.getLineNumber()
            };
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SYNC — replaces quote lines with the current canvas state
    // ─────────────────────────────────────────────────────────────────────────
    public static Map<String,Object> syncProductsToQuote(String quoteId, String productsJson) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (String.isBlank(quoteId)) throw new AuraHandledException('Quote ID is null');

            // Second delete inside the savepoint: no-op when clearAndAddAllBundles
            // already deleted lines, but acts as safety net for direct callers.
            delete [SELECT Id FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :quoteId];

            SBQQ__Quote__c q = [SELECT Id, CurrencyIsoCode, SBQQ__PricebookId__c,
                                       SBQQ__StartDate__c, SBQQ__SubscriptionTerm__c
                                 FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1];
            List<Object> rawItems = (List<Object>) JSON.deserializeUntyped(productsJson);

            // Collect all product IDs (parents + bundle children)
            Set<Id> pIds = new Set<Id>();
            for (Object o : rawItems) {
                Map<String,Object> item = (Map<String,Object>) o;
                Object pidRaw = item.get('productId');
                if (pidRaw != null) pIds.add((Id) String.valueOf(pidRaw));
                List<Object> opts = (List<Object>) item.get('bundleProducts');
                if (opts == null) opts = (List<Object>) item.get('options');
                if (opts != null) {
                    for (Object oo : opts) {
                        Object opidRaw = ((Map<String,Object>) oo).get('productId');
                        if (opidRaw != null) pIds.add((Id) String.valueOf(opidRaw));
                    }
                }
            }

            // Price lookup
            Map<Id, PricebookEntry> pbeMap = new Map<Id, PricebookEntry>();
            for (PricebookEntry pbe : [SELECT Id, Product2Id, UnitPrice
                                        FROM PricebookEntry
                                        WHERE Product2Id IN :pIds
                                          AND Pricebook2Id = :q.SBQQ__PricebookId__c
                                          AND CurrencyIsoCode = :q.CurrencyIsoCode
                                          AND IsActive = true]) {
                pbeMap.put(pbe.Product2Id, pbe);
            }

            // ── Insert parent lines ──────────────────────────────────────────
            Integer num = 1;
            List<SBQQ__QuoteLine__c> parents = new List<SBQQ__QuoteLine__c>();
            List<Map<String,Object>> metas   = new List<Map<String,Object>>();

            for (Object o : rawItems) {
                Map<String,Object> item = (Map<String,Object>) o;
                Object pidRaw = item.get('productId');
                if (pidRaw == null) continue;
                Id pid = (Id) String.valueOf(pidRaw);
                if (!pbeMap.containsKey(pid)) continue;

                List<Object> opts = (List<Object>) item.get('bundleProducts');
                if (opts == null) opts = (List<Object>) item.get('options');
                Boolean isB = opts != null && !opts.isEmpty();

                Object qtyRaw  = item.get('quantity');
                Decimal qty    = (qtyRaw != null && String.valueOf(qtyRaw) != 'null')
                                 ? Decimal.valueOf(String.valueOf(qtyRaw)) : 1;
                Object discRaw = item.get('manualDiscount');
                Decimal manAmt = (discRaw != null && String.valueOf(discRaw) != 'null')
                                 ? Decimal.valueOf(String.valueOf(discRaw)) : 0;

                Decimal basePrice   = isB ? 0 : pbeMap.get(pid).UnitPrice;
                Decimal netPriceVal = isB ? 0 : Math.max(basePrice - manAmt, 0);
                Date    startDate   = q.SBQQ__StartDate__c != null ? q.SBQQ__StartDate__c : Date.today();
                Integer subTerm     = q.SBQQ__SubscriptionTerm__c != null ? q.SBQQ__SubscriptionTerm__c.intValue() : 12;
                parents.add(new SBQQ__QuoteLine__c(
                    SBQQ__Quote__c            = quoteId,
                    SBQQ__Product__c          = pid,
                    SBQQ__PricebookEntryId__c = pbeMap.get(pid).Id,
                    SBQQ__Quantity__c         = qty,
                    SBQQ__ListPrice__c        = basePrice,
                    SBQQ__NetPrice__c         = netPriceVal,
                    SBQQ__CustomerPrice__c    = netPriceVal,
                    SBQQ__Number__c           = num++,
                    SBQQ__Bundle__c           = isB,
                    SBQQ__PricingMethod__c    = 'List',
                    SBQQ__StartDate__c        = startDate,
                    SBQQ__EndDate__c          = startDate.addMonths(subTerm),
                    SBQQ__SubscriptionTerm__c = subTerm,
                    Manual_Discount_Amt__c    = manAmt > 0 ? manAmt : null
                ));
                metas.add(item);
            }
            if (!parents.isEmpty()) insert parents;

            // ── Re-number parents and insert children ────────────────────────
            Integer globalNum = 1;
            List<SBQQ__QuoteLine__c> children = new List<SBQQ__QuoteLine__c>();
            for (Integer i = 0; i < parents.size(); i++) {
                parents[i].SBQQ__Number__c = globalNum++;
                List<Object> opts = (List<Object>) metas[i].get('bundleProducts');
                if (opts == null) opts = (List<Object>) metas[i].get('options');
                if (opts != null) {
                    for (Object oo : opts) {
                        Map<String,Object> om = (Map<String,Object>) oo;
                        Id opid = (Id) String.valueOf(om.get('productId'));
                        if (!pbeMap.containsKey(opid)) continue;
                        Decimal oqty = (om.get('quantity') != null && String.valueOf(om.get('quantity')) != 'null')
                                       ? Decimal.valueOf(String.valueOf(om.get('quantity'))) : 1;
                        Id optId = (om.get('optionId') != null) ? (Id) String.valueOf(om.get('optionId')) : null;
                        Boolean isBundledVal = false;
                        Object isBundledRaw = om.get('isBundled');
                        if (isBundledRaw != null) {
                            isBundledVal = Boolean.valueOf(isBundledRaw);
                        }
                        children.add(new SBQQ__QuoteLine__c(
                            SBQQ__Quote__c            = quoteId,
                            SBQQ__Product__c          = opid,
                            SBQQ__PricebookEntryId__c = pbeMap.get(opid).Id,
                            SBQQ__Quantity__c         = oqty,
                            SBQQ__ListPrice__c        = pbeMap.get(opid).UnitPrice,
                            SBQQ__NetPrice__c         = isBundledVal ? 0 : pbeMap.get(opid).UnitPrice,
                            SBQQ__CustomerPrice__c    = isBundledVal ? 0 : pbeMap.get(opid).UnitPrice,
                            SBQQ__RequiredBy__c       = parents[i].Id,
                            SBQQ__ProductOption__c    = optId,
                            SBQQ__OptionType__c       = 'Component',
                            SBQQ__OptionLevel__c      = 1,
                            SBQQ__PricingMethod__c    = 'List',
                            SBQQ__Bundled__c          = isBundledVal,
                            SBQQ__Number__c           = globalNum++
                        ));
                    }
                }
            }
            update parents;
            if (!children.isEmpty()) insert children;

            try {
                update new SBQQ__Quote__c(Id = quoteId, SBQQ__Primary__c = true);
            } catch (Exception ex) { }

            return calculatePricing(quoteId);
        } catch (Exception e) {
            Database.rollback(sp);
            return new Map<String,Object>{
                'success' => false,
                'error'   => e.getMessage() + ' | line: ' + e.getLineNumber()
            };
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CALCULATE — triggers CPQ engine and returns enriched line data
    // ─────────────────────────────────────────────────────────────────────────
    public static Map<String,Object> calculatePricing(String quoteId) {
        Map<String,Object> result = new Map<String,Object>();
        if (String.isBlank(quoteId))
            return new Map<String,Object>{'success' => false, 'error' => 'Quote ID null'};
        try {
            // Step 1 — Try CPQ's own engine (handles subscription terms, etc.)
            try {
                String qJson = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', quoteId);
                if (String.isNotBlank(qJson)) {
                    String cJson = SBQQ.ServiceRouter.load('SBQQ.QuoteAPI.QuoteCalculator', quoteId, qJson);
                    if (String.isNotBlank(cJson)) SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', cJson);
                }
            } catch (Exception cpqe) {
                System.debug('CPQ API skip: ' + cpqe.getMessage());
            }

            // Step 2 — Always run our custom calculation so that:
            //   • global promotional discounts are capped at 20% of list price
            //   • manager-approved manual discounts are fully applied beyond the cap
            //   • a consistent Discount_Breakdown__c is written for every line
            try {
                runFallbackCalculation(quoteId);
            } catch (Exception fe) {
                System.debug('Fallback calculation failed: ' + fe.getMessage());
            }

            Decimal sub = 0, net = 0;
            List<Map<String,Object>> linesResult = new List<Map<String,Object>>();
            SBQQ__Quote__c quote = [SELECT Id, SBQQ__Uncalculated__c, Discount_Approved__c, High_Discount_Approval__c
                                    FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1];
            result.put('isCalculating', quote.SBQQ__Uncalculated__c);
            result.put('discountApproved', quote.Discount_Approved__c);
            result.put('highDiscountApproval', quote.High_Discount_Approval__c);

            // approvedNetPriceMap — read the net prices already written by runFallbackCalculation
            // so the LWC displays the same value as the DB without recomputing here.
            Map<Id, Decimal> approvedNetPriceMap = new Map<Id, Decimal>();

            List<SBQQ__QuoteLine__c> allLines = [
                SELECT Id, SBQQ__Product__c, SBQQ__ProductCode__c,
                       SBQQ__Product__r.Name, SBQQ__Product__r.Family,
                       SBQQ__Product__r.SBQQ__ChargeType__c,
                       SBQQ__Quantity__c, SBQQ__ListPrice__c, SBQQ__NetPrice__c,
                       SBQQ__ListTotal__c, SBQQ__NetTotal__c,
                       Discount_Breakdown__c, SBQQ__RequiredBy__c,
                       SBQQ__Bundle__c, SBQQ__Discount__c, SBQQ__Bundled__c,
                       Manual_Discount_Amt__c, SBQQ__ProductOption__c
                FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :quoteId
            ];

            // Roll up child totals to parents
            Map<Id, Decimal> parentListRollup = new Map<Id, Decimal>();
            Map<Id, Decimal> parentNetRollup  = new Map<Id, Decimal>();
            for (SBQQ__QuoteLine__c ql : allLines) {
                if (ql.SBQQ__RequiredBy__c != null) {
                    Decimal lt = ql.SBQQ__ListTotal__c != null ? ql.SBQQ__ListTotal__c
                                 : ((ql.SBQQ__ListPrice__c != null ? ql.SBQQ__ListPrice__c : 0) * ql.SBQQ__Quantity__c);
                    Decimal nt = approvedNetPriceMap.containsKey(ql.Id)
                                 ? (ql.SBQQ__ListPrice__c - ql.Manual_Discount_Amt__c) * ql.SBQQ__Quantity__c
                                 : (ql.SBQQ__NetTotal__c != null ? ql.SBQQ__NetTotal__c
                                 : ((ql.SBQQ__NetPrice__c != null ? ql.SBQQ__NetPrice__c : (ql.SBQQ__ListPrice__c != null ? ql.SBQQ__ListPrice__c : 0)) * ql.SBQQ__Quantity__c));
                    if (!parentListRollup.containsKey(ql.SBQQ__RequiredBy__c)) {
                        parentListRollup.put(ql.SBQQ__RequiredBy__c, 0);
                        parentNetRollup.put(ql.SBQQ__RequiredBy__c, 0);
                    }
                    parentListRollup.put(ql.SBQQ__RequiredBy__c, parentListRollup.get(ql.SBQQ__RequiredBy__c) + lt);
                    parentNetRollup.put(ql.SBQQ__RequiredBy__c, parentNetRollup.get(ql.SBQQ__RequiredBy__c) + nt);
                }
            }

            for (SBQQ__QuoteLine__c line : allLines) {
                Decimal qty  = line.SBQQ__Quantity__c  != null ? line.SBQQ__Quantity__c  : 1;
                Decimal lp   = line.SBQQ__ListPrice__c != null ? line.SBQQ__ListPrice__c : 0;
                Decimal np   = approvedNetPriceMap.containsKey(line.Id)
                               ? (lp - (line.Manual_Discount_Amt__c != null ? line.Manual_Discount_Amt__c : 0))
                               : (line.SBQQ__NetPrice__c != null ? line.SBQQ__NetPrice__c : lp);
                Boolean isB  = line.SBQQ__Bundle__c == true;
                
                Decimal lt   = line.SBQQ__ListTotal__c != null ? line.SBQQ__ListTotal__c : (lp * qty);
                Decimal nt   = approvedNetPriceMap.containsKey(line.Id)
                               ? np * qty
                               : (line.SBQQ__NetTotal__c != null ? line.SBQQ__NetTotal__c : (np * qty));
                
                if (isB && parentListRollup.containsKey(line.Id)) {
                    if (lt == 0) lt = parentListRollup.get(line.Id);
                    if (nt == 0) nt = parentNetRollup.get(line.Id);
                }
                if (line.SBQQ__RequiredBy__c == null) { sub += lt; net += nt; }

                Decimal discAmt = (lt - nt);
                Decimal discPct = 0;
                if (lt > 0 && discAmt > 0 && line.SBQQ__Bundled__c != true) {
                    discPct = (discAmt / lt) * 100;
                    if (discPct >= 99.9 && (line.SBQQ__Discount__c == null || line.SBQQ__Discount__c < 1)) discPct = 0;
                }
                if (line.SBQQ__Discount__c != null && line.SBQQ__Discount__c > discPct)
                    discPct = line.SBQQ__Discount__c;

                linesResult.add(new Map<String,Object>{
                    'id'              => line.Id,
                    'productId'       => line.SBQQ__Product__c,
                    'productCode'     => line.SBQQ__ProductCode__c,
                    'name'            => (line.SBQQ__Product__r != null ? line.SBQQ__Product__r.Name : line.SBQQ__ProductCode__c),
                    'family'          => (line.SBQQ__Product__r != null ? line.SBQQ__Product__r.Family : ''),
                    'chargeType'      => (line.SBQQ__Product__r != null ? line.SBQQ__Product__r.SBQQ__ChargeType__c : ''),
                    'quantity'        => qty,
                    'unitPrice'       => lp,
                    'unitNetPrice'    => (isB && qty > 0 ? nt / qty : np),
                    'lineTotal'       => nt,
                    'breakdown'       => line.Discount_Breakdown__c,
                    'discountAmount'  => (line.SBQQ__Bundled__c == true ? 0 : discAmt.setScale(2)),
                    'discountPercent' => discPct.setScale(2),
                    'requiredBy'      => line.SBQQ__RequiredBy__c,
                    'isBundle'        => isB,
                    'manualDiscount'  => line.Manual_Discount_Amt__c != null ? line.Manual_Discount_Amt__c : 0,
                    'optionId'        => line.SBQQ__ProductOption__c,
                    'isBundled'       => line.SBQQ__Bundled__c == true
                });
            }
            result.put('success',  true);
            result.put('subtotal', sub);
            result.put('netTotal', net);
            result.put('discount', (sub - net));
            result.put('lines',    linesResult);
        } catch (Exception e) {
            result.put('success', false);
            result.put('error',   e.getMessage() + ' | line: ' + e.getLineNumber());
        }
        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GET QUOTE LINES — used by the configurator canvas on load
    // ─────────────────────────────────────────────────────────────────────────
    public static List<Map<String,Object>> getQuoteLines(String quoteId) {
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        if (String.isBlank(quoteId)) return result;
        List<SBQQ__QuoteLine__c> lines = [
            SELECT Id, SBQQ__Product__c, SBQQ__ProductCode__c,
                   SBQQ__Product__r.Name, SBQQ__Product__r.Family,
                   SBQQ__Product__r.SBQQ__ChargeType__c,
                   SBQQ__Quantity__c, SBQQ__NetPrice__c, SBQQ__ListPrice__c,
                   SBQQ__RequiredBy__c, SBQQ__Number__c, SBQQ__Bundled__c,
                   Discount_Breakdown__c, SBQQ__Discount__c, Manual_Discount_Amt__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :quoteId
            ORDER BY SBQQ__Number__c ASC
        ];

        Map<Id, Map<String,Object>> parentMap = new Map<Id, Map<String,Object>>();
        for (SBQQ__QuoteLine__c ql : lines) {
            if (ql.SBQQ__RequiredBy__c == null) {
                Decimal lp  = ql.SBQQ__ListPrice__c != null ? ql.SBQQ__ListPrice__c : 0;
                Decimal np  = ql.SBQQ__NetPrice__c  != null ? ql.SBQQ__NetPrice__c  : lp;
                Decimal qty = ql.SBQQ__Quantity__c  != null ? ql.SBQQ__Quantity__c  : 1;
                Map<String,Object> line = new Map<String,Object>{
                    'id'             => ql.SBQQ__Product__c,
                    'productId'      => ql.SBQQ__Product__c,
                    'name'           => (ql.SBQQ__Product__r != null ? ql.SBQQ__Product__r.Name : ql.SBQQ__ProductCode__c),
                    'productCode'    => ql.SBQQ__ProductCode__c,
                    'family'         => (ql.SBQQ__Product__r != null ? ql.SBQQ__Product__r.Family : ''),
                    'chargeType'     => (ql.SBQQ__Product__r != null ? ql.SBQQ__Product__r.SBQQ__ChargeType__c : ''),
                    'quantity'       => qty,
                    'unitPrice'      => lp,
                    'unitNetPrice'   => np,
                    'lineTotal'      => (np * qty),
                    'discountAmount' => (lp - np) * qty,
                    'manualDiscount' => ql.Manual_Discount_Amt__c != null ? ql.Manual_Discount_Amt__c : 0,
                    'discountReason' => ql.Discount_Breakdown__c,
                    'bundleProducts' => new List<Map<String,Object>>()
                };
                result.add(line);
                parentMap.put(ql.Id, line);
            }
        }
        for (SBQQ__QuoteLine__c ql : lines) {
            if (ql.SBQQ__RequiredBy__c != null && parentMap.containsKey(ql.SBQQ__RequiredBy__c)) {
                Map<String,Object> parent = parentMap.get(ql.SBQQ__RequiredBy__c);
                List<Map<String,Object>> opts = (List<Map<String,Object>>) parent.get('bundleProducts');
                Decimal qty = ql.SBQQ__Quantity__c != null ? ql.SBQQ__Quantity__c : 1;
                Decimal np  = ql.SBQQ__NetPrice__c  != null ? ql.SBQQ__NetPrice__c  : 0;
                Decimal lp  = ql.SBQQ__ListPrice__c != null ? ql.SBQQ__ListPrice__c : 0;
                opts.add(new Map<String,Object>{
                    'id'          => ql.SBQQ__Product__c,
                    'productId'   => ql.SBQQ__Product__c,
                    'name'        => (ql.SBQQ__Product__r != null ? ql.SBQQ__Product__r.Name : ql.SBQQ__ProductCode__c),
                    'productCode' => ql.SBQQ__ProductCode__c,
                    'quantity'    => qty,
                    'unitPrice'   => lp,
                    'lineTotal'   => np * qty,
                    'isBundled'   => ql.SBQQ__Bundled__c
                });
                parent.put('family', 'Bundles');
            }
        }
        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INVOCABLE — called from the APPROVED DISCOUNT Flow
    // ─────────────────────────────────────────────────────────────────────────
    public static void calculatePricingInvocable(List<Id> quoteIds) {
        for (Id quoteId : quoteIds) {
            // Step 1 — CPQ engine (optional; errors are swallowed silently)
            try {
                String qJson = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', quoteId);
                if (String.isNotBlank(qJson)) {
                    String cJson = SBQQ.ServiceRouter.load('SBQQ.QuoteAPI.QuoteCalculator', quoteId, qJson);
                    if (String.isNotBlank(cJson)) SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', cJson);
                }
            } catch (Exception e) {
                System.debug('calculatePricingInvocable CPQ skip: ' + e.getMessage());
            }
            // Step 2 — Always run our calculation:
            //   • global discounts capped at 20% of list price
            //   • manager-approved manual discounts applied beyond the cap
            try {
                runFallbackCalculation(quoteId);
            } catch (Exception fe) {
                System.debug('calculatePricingInvocable fallback failed: ' + fe.getMessage());
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SUBMIT FOR APPROVAL — called from the LWC when discount exceeds 20%
    // Submits the Quote through the Salesforce Approval Process configured
    // for high discounts. The Approval Process approval action must set
    // Discount_Approved__c = true. The rejection action must call
    // handleDiscountRejection (via a Flow action or Process Builder).
    // ─────────────────────────────────────────────────────────────────────────
    public static Map<String,Object> submitHighDiscountForApproval(Id quoteId, String comments) {
        try {
            SBQQ__Quote__c quote = [
                SELECT Id, High_Discount_Approval__c, Discount_Approved__c,
                       SBQQ__Status__c
                FROM SBQQ__Quote__c
                WHERE Id = :quoteId
                LIMIT 1
            ];

            // Already approved — nothing to do
            if (quote.Discount_Approved__c == true) {
                return new Map<String,Object>{ 'success' => true, 'message' => 'Discount already approved.' };
            }

            // No high discount on this quote — nothing to submit
            if (quote.High_Discount_Approval__c != true) {
                return new Map<String,Object>{ 'success' => false, 'message' => 'No discount exceeding 20% found on this quote.' };
            }

            // Mark the quote as In Review so the LWC can reflect the state
            // ('Pending Approval' is not a valid SBQQ__Status__c picklist value)
            update new SBQQ__Quote__c(
                Id               = quoteId,
                SBQQ__Status__c  = 'In Review'
            );

            // Submit through the configured Salesforce Approval Process.
            // Salesforce automatically selects the matching Approval Process
            // based on the entry criteria — no hardcoded process name needed.
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(quoteId);
            req.setComments(String.isNotBlank(comments)
                ? comments
                : 'Discount exceeds 20% — manager approval required.');
            req.setSubmitterId(UserInfo.getUserId());

            Approval.ProcessResult result = Approval.process(req);

            return new Map<String,Object>{
                'success'    => result.isSuccess(),
                'instanceId' => result.getInstanceId(),
                'status'     => result.getInstanceStatus(),
                'errors'     => String.valueOf(result.getErrors())
            };
        } catch (Exception e) {
            return new Map<String,Object>{
                'success' => false,
                'error'   => e.getMessage() + ' | line: ' + e.getLineNumber()
            };
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HANDLE REJECTION — called when manager rejects the approval request.
    // Resets all manual discounts that exceed 20% back to the 20% maximum,
    // clears the approval flags, and recalculates pricing.
    // Call this from the Approval Process rejection action (via a Flow).
    // ─────────────────────────────────────────────────────────────────────────
    public static Map<String,Object> handleDiscountRejection(Id quoteId) {
        try {
            // Find lines where the manual discount exceeds 20% of list price
            List<SBQQ__QuoteLine__c> lines = [
                SELECT Id, SBQQ__ListPrice__c, SBQQ__Quantity__c, Manual_Discount_Amt__c
                FROM SBQQ__QuoteLine__c
                WHERE SBQQ__Quote__c = :quoteId
                  AND Manual_Discount_Amt__c != null
                  AND Manual_Discount_Amt__c > 0
            ];

            List<SBQQ__QuoteLine__c> toUpdate = new List<SBQQ__QuoteLine__c>();
            for (SBQQ__QuoteLine__c ln : lines) {
                Decimal lp         = ln.SBQQ__ListPrice__c != null ? ln.SBQQ__ListPrice__c : 0;
                Decimal maxDiscount = lp * 0.20;
                // Only reset lines where the discount actually exceeds 20%
                if (ln.Manual_Discount_Amt__c > maxDiscount) {
                    toUpdate.add(new SBQQ__QuoteLine__c(
                        Id                    = ln.Id,
                        Manual_Discount_Amt__c = null,
                        Discount_Breakdown__c  = 'Discount rejected: discount not applied'
                    ));
                }
            }
            if (!toUpdate.isEmpty()) update toUpdate;

            // Clear the approval flags and reset status
            update new SBQQ__Quote__c(
                Id                        = quoteId,
                Discount_Approved__c      = false,
                High_Discount_Approval__c  = false,
                SBQQ__Status__c           = 'Draft'
            );

            // Recalculate with the reset (capped) discounts
            return calculatePricing(quoteId);
        } catch (Exception e) {
            return new Map<String,Object>{
                'success' => false,
                'error'   => e.getMessage() + ' | line: ' + e.getLineNumber()
            };
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPER — applies approved discount override after CPQ calculation
    // Called from both calculatePricing and calculatePricingInvocable so
    // the logic lives in one place and both paths respect the manager's approval.
    // If CPQ re-applies the 20% cap during ServiceRouter.save, this method
    // corrects the net price directly on the QuoteLine.
    // ─────────────────────────────────────────────────────────────────────────
    private static void applyApprovedDiscountOverride(Id quoteId) {
        // Read the flag directly from DB (not from the in-memory session)
        SBQQ__Quote__c quote = [
            SELECT Id, Discount_Approved__c
            FROM SBQQ__Quote__c
            WHERE Id = :quoteId
            LIMIT 1
        ];
        // Nothing to do if the discount has not been approved
        if (quote.Discount_Approved__c != true) return;

        // Find all lines that carry a manager-approved manual discount
        List<SBQQ__QuoteLine__c> approvedLines = [
            SELECT Id, SBQQ__ListPrice__c, Manual_Discount_Amt__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :quoteId
              AND Manual_Discount_Amt__c != null
              AND Manual_Discount_Amt__c > 0
        ];

        List<SBQQ__QuoteLine__c> toUpdate = new List<SBQQ__QuoteLine__c>();
        for (SBQQ__QuoteLine__c ln : approvedLines) {
            Decimal lp = ln.SBQQ__ListPrice__c != null ? ln.SBQQ__ListPrice__c : 0;
            // Apply the FULL manual discount — no 20% cap
            Decimal np = Math.max(lp - ln.Manual_Discount_Amt__c, 0);
            toUpdate.add(new SBQQ__QuoteLine__c(
                Id                    = ln.Id,
                SBQQ__NetPrice__c     = np,
                Discount_Breakdown__c = 'Approved: full manual discount of '
                    + ln.Manual_Discount_Amt__c.setScale(2) + ' applied'
            ));
        }
        if (!toUpdate.isEmpty()) Database.update(toUpdate, false);
    }

    public static void runFallbackCalculation(String quoteId) {
        // Query Quote
        SBQQ__Quote__c q = [SELECT Id, SBQQ__Account__c, SBQQ__StartDate__c, CurrencyIsoCode,
                                   Discount_Approved__c, SBQQ__Status__c
                            FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1];
                            
        Id accountId = q.SBQQ__Account__c;
        String currencyCode = q.CurrencyIsoCode != null ? q.CurrencyIsoCode : 'MAD';
        
        // Query Account
        Boolean isEmployee = false;
        Boolean isStudent = false;
        Boolean hasContract = false;
        Boolean hasOrder = false;
        String billingCountry = '';
        
        if (accountId != null) {
            Account acc = [SELECT Is_Student__c, Is_Telecom_Employee__c, BillingCountry,
                                  (SELECT Id FROM Orders WHERE Status = 'Activated' LIMIT 1),
                                  (SELECT Id FROM Contracts WHERE Status = 'Activated' LIMIT 1)
                           FROM Account WHERE Id = :accountId LIMIT 1];
            isEmployee = acc.Is_Telecom_Employee__c == true;
            isStudent = acc.Is_Student__c == true;
            hasContract = acc.Contracts != null && !acc.Contracts.isEmpty();
            hasOrder = acc.Orders != null && !acc.Orders.isEmpty();
            billingCountry = acc.BillingCountry != null ? acc.BillingCountry : '';
        }
        
        Boolean isNew = !hasContract && !hasOrder;
        String c = billingCountry.toLowerCase().trim();
        Boolean isMorocco = (c == 'morocco' || c == 'maroc' || c == 'ma');
        
        Date quoteDate = q.SBQQ__StartDate__c != null ? q.SBQQ__StartDate__c : Date.today();
        Boolean isRamadan = isMorocco && (
            (quoteDate >= Date.newInstance(2026, 2, 28) && quoteDate <= Date.newInstance(2026, 3, 30)) ||
            (quoteDate >= Date.newInstance(2027, 2, 17) && quoteDate <= Date.newInstance(2027, 3, 18))
        );
        
        Boolean isDiscountApproved = (q.Discount_Approved__c == true || q.SBQQ__Status__c == 'Approved');
        String approvalSource = 'FALLBACK_DB_' + q.Discount_Approved__c + '_UI_' + q.SBQQ__Status__c;
        
        // Currency rate
        Map<String, Decimal> rates = new Map<String, Decimal>{ 'MAD' => 1.0, 'USD' => 0.099, 'EUR' => 0.091 };
        Decimal rate = rates.containsKey(currencyCode) ? rates.get(currencyCode) : 1.0;
        String sym = currencyCode;
        
        Decimal globalDiscount = 0;
        List<String> globalBreakdown = new List<String>();
        if (isEmployee) {
            Decimal e = toLocal(80, rate);
            globalDiscount += e;
            globalBreakdown.add('Employee: -' + e + ' ' + sym);
        } else if (isStudent) {
            Decimal s = toLocal(30, rate);
            globalDiscount += s;
            globalBreakdown.add('Student: -' + s + ' ' + sym);
        }
        if (isNew) {
            Decimal nw = toLocal(40, rate);
            globalDiscount += nw;
            globalBreakdown.add('New Customer: -' + nw + ' ' + sym);
        }
        if (isRamadan) {
            Decimal rm = toLocal(30, rate);
            globalDiscount += rm;
            globalBreakdown.add('Ramadan: -' + rm + ' ' + sym);
        }
        String globalLabel = String.join(globalBreakdown, ' | ');
        
        q.Ramadan_Discount_Amount__c = isRamadan ? toLocal(30, rate) : 0;
        
        // Query Quote Lines
        List<SBQQ__QuoteLine__c> lines = [
            SELECT Id, SBQQ__Product__c, SBQQ__ProductCode__c,
                   SBQQ__Product__r.Name, SBQQ__Product__r.Family,
                   SBQQ__Product__r.SBQQ__ChargeType__c,
                   SBQQ__Quantity__c, SBQQ__ListPrice__c, SBQQ__NetPrice__c,
                   SBQQ__ListTotal__c, SBQQ__NetTotal__c,
                   Discount_Breakdown__c, SBQQ__RequiredBy__c,
                   SBQQ__Bundle__c, SBQQ__Discount__c, SBQQ__Bundled__c,
                   Manual_Discount_Amt__c
            FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :quoteId
        ];
        
        // Pass 1: analyze bundles and devices
        Set<String> bundleCodes = new Set<String>();
        Integer bundleCount = 0;
        Decimal deviceCount = 0;
        Boolean hasMobile = false;
        Boolean hasHome = false;
        Boolean hasFiber = false;
        
        for (SBQQ__QuoteLine__c line : lines) {
            String code = line.SBQQ__ProductCode__c != null ? line.SBQQ__ProductCode__c : '';
            String family = line.SBQQ__Product__r.Family != null ? line.SBQQ__Product__r.Family : '';
            if (family == 'Bundles' && !bundleCodes.contains(code)) {
                bundleCodes.add(code);
                bundleCount++;
            }
            if (family == 'Devices') {
                deviceCount += (line.SBQQ__Quantity__c != null ? line.SBQQ__Quantity__c : 0);
            }
            if (code == 'MOB-Bun' || code == 'MOB-FAMILY-SHARE-PACK') hasMobile = true;
            if (code == 'BND-TV-HOME' || code == 'BND-SMART-SEC') hasHome = true;
            if (code == 'NET-FIB500' || code == 'NET-FIB1G' || code == 'NET-BUS1.5G') hasFiber = true;
        }
        
        // Pass 2: calculate line-level discounts
        List<LineData> lineDataList = new List<LineData>();
        Decimal totalNet = 0;
        Boolean hasHighDiscount = false;
        List<String> highDiscountProducts = new List<String>();
        Decimal totalManualDiscountAmt = 0;
        
        for (SBQQ__QuoteLine__c line : lines) {
            String code = line.SBQQ__ProductCode__c != null ? line.SBQQ__ProductCode__c : '';
            String family = line.SBQQ__Product__r.Family != null ? line.SBQQ__Product__r.Family : '';
            String chargeType = line.SBQQ__Product__r.SBQQ__ChargeType__c != null ? line.SBQQ__Product__r.SBQQ__ChargeType__c : '';
            Decimal qty = line.SBQQ__Quantity__c != null ? line.SBQQ__Quantity__c : 0;
            Decimal listPrice = line.SBQQ__ListPrice__c != null ? line.SBQQ__ListPrice__c : 0;
            Decimal manualAmt = line.Manual_Discount_Amt__c != null ? line.Manual_Discount_Amt__c : 0;
            Boolean isBundled = line.SBQQ__Bundled__c == true;
            
            Boolean isRecurring = (chargeType == 'Recurring')
                || family == 'Plans'
                || family == 'Internet'
                || family == 'TV'
                || code == 'MOB-UNLTD' || code == 'MOB-5G-PREM' || code == 'MOB-5G-STRT'
                || code == 'NET-FIB500' || code == 'NET-FIB1G' || code == 'NET-BUS1.5G'
                || code == 'BIZ-FIB1G' || code == 'BIZ-FIB2G' || code == 'BIZ-FIB3G';
                
            Decimal base = listPrice * qty;
            Decimal lineDisc = 0;
            List<String> breakdown = new List<String>();
            
            // Bundled options are FREE
            if (isBundled) {
                line.SBQQ__NetPrice__c = 0;
                line.SBQQ__CustomerPrice__c = 0;
                line.Discount_Breakdown__c = 'Included in bundle';
                
                LineData ld = new LineData();
                ld.line = line;
                ld.family = family;
                ld.base = 0;
                ld.net = 0;
                ld.lineDisc = 0;
                ld.isExempt = true;
                ld.breakdown = new List<String>();
                ld.skip = true;
                lineDataList.add(ld);
                continue;
            }
            
            Boolean isExempt = (
                (code == 'SRV-INST' && bundleCount >= 2) ||
                (code == 'HW-WIFI-BOOST' && hasFiber) ||
                (code == 'ADD-TV-PREMIUM' && isStudent)
            );
            
            if (family == 'Bundles') {
                LineData ld = new LineData();
                ld.line = line;
                ld.family = family;
                ld.base = base;
                ld.net = 0;
                ld.lineDisc = 0;
                ld.isExempt = true;
                ld.breakdown = new List<String>();
                ld.skip = false;
                lineDataList.add(ld);
                continue;
            }
            
            if (manualAmt > 0) {
                Decimal totalManual = manualAmt * qty;
                totalManualDiscountAmt += totalManual;
                lineDisc += totalManual;
                breakdown.add('Manual Discount: -' + totalManual.setScale(2) + ' ' + sym);
            }
            
            if (code == 'SRV-INST' && bundleCount >= 2) {
                lineDisc += base;
                breakdown.add('Free Install: -' + base.setScale(2) + ' ' + sym);
            }
            if (code == 'HW-WIFI-BOOST' && hasFiber) {
                lineDisc += base;
                breakdown.add('Free WiFi Booster: -' + base.setScale(2) + ' ' + sym);
            }
            if (code == 'ADD-TV-PREMIUM' && isStudent) {
                lineDisc += base;
                breakdown.add('Student Premium Free: -' + base.setScale(2) + ' ' + sym);
            }
            
            if (bundleCount >= 2 && isRecurring && code != 'SRV-INST' && code != 'HW-WIFI-BOOST') {
                if (hasMobile && hasHome) {
                    Decimal combo = base * 0.20;
                    lineDisc += combo;
                    breakdown.add('Home+Mobile Combo 20%: -' + combo.setScale(2) + ' ' + sym);
                } else {
                    Decimal multi = base * 0.15;
                    lineDisc += multi;
                    breakdown.add('Bundle 15%: -' + multi.setScale(2) + ' ' + sym);
                }
            }
            
            if (family == 'Devices' && deviceCount >= 3) {
                Decimal vol = base * 0.10;
                lineDisc += vol;
                breakdown.add('Device Volume 10%: -' + vol.setScale(2) + ' ' + sym);
            }
            
            if (!isExempt && base > 0) {
                Decimal maxDisc = base * 0.20;
                if (lineDisc > maxDisc) {
                    if (!isDiscountApproved) {
                        hasHighDiscount = true;
                        String productName = line.SBQQ__Product__r.Name != null ? line.SBQQ__Product__r.Name : code;
                        highDiscountProducts.add(productName);
                        breakdown.add('Capped at 20%: was -' + lineDisc.setScale(2) + ' ' + sym + ', max -' + maxDisc.setScale(2) + ' ' + sym);
                        lineDisc = maxDisc;
                    } else {
                        breakdown.add('Approved discount: -' + lineDisc.setScale(2) + ' ' + sym + ' (cap bypassed)');
                    }
                }
            }
            
            Decimal net = Math.max(base - lineDisc, 0);
            totalNet += net;
            
            LineData ld = new LineData();
            ld.line = line;
            ld.family = family;
            ld.base = base;
            ld.net = net;
            ld.lineDisc = lineDisc;
            ld.isExempt = isExempt;
            ld.breakdown = breakdown;
            ld.skip = false;
            lineDataList.add(ld);
        }
        
        q.High_Discount_Approval__c = hasHighDiscount && !isDiscountApproved;
        q.High_Discount_Products__c = String.join(highDiscountProducts, ', ');
        q.Total_Manual_Discount_Amount__c = totalManualDiscountAmt;
        
        // Pass 3: apply global discounts and save
        for (LineData ld : lineDataList) {
            if (ld.skip) continue;
            SBQQ__QuoteLine__c line = ld.line;
            List<String> breakdown = new List<String>(ld.breakdown);
            
            if (ld.family == 'Bundles') {
                line.Discount_Breakdown__c = String.isNotBlank(globalLabel) ? 'GLOBAL: ' + globalLabel : 'No Discount';
                line.SBQQ__NetPrice__c = 0;
                line.SBQQ__CustomerPrice__c = 0;
                continue;
            }
            
            Decimal lineShare = 0;
            if (globalDiscount > 0 && totalNet > 0) {
                lineShare = (ld.net / totalNet) * globalDiscount;
            }
            
            if (!ld.isExempt && ld.base > 0) {
                if (!isDiscountApproved) {
                    // Without approval: total (manual + global) must not exceed 20% of list price
                    Decimal maxTotal = ld.base * 0.20;
                    if (ld.lineDisc + lineShare > maxTotal) {
                        Decimal allowed = Math.max(maxTotal - ld.lineDisc, 0);
                        breakdown.add('Global capped at 20%: was -' + lineShare.setScale(2) + ' ' + sym + ', allowed -' + allowed.setScale(2) + ' ' + sym);
                        lineShare = allowed;
                    }
                } else {
                    // With manager approval: manual discount is uncapped (approved by manager).
                    // Global promotional discount is still always capped at 20% of list price.
                    Decimal maxGlobal = ld.base * 0.20;
                    if (lineShare > maxGlobal) {
                        breakdown.add('Global capped at 20%: was -' + lineShare.setScale(2) + ' ' + sym + ', max -' + maxGlobal.setScale(2) + ' ' + sym);
                        lineShare = maxGlobal;
                    }
                }
            }
            
            Decimal finalNetTotal = Math.max(ld.net - lineShare, 0);
            Decimal qty = line.SBQQ__Quantity__c != null ? line.SBQQ__Quantity__c : 1;
            Decimal perUnit = qty > 0 ? (finalNetTotal / qty) : finalNetTotal;
            
            line.SBQQ__NetPrice__c = perUnit.setScale(2, System.RoundingMode.HALF_UP);
            line.SBQQ__CustomerPrice__c = perUnit.setScale(2, System.RoundingMode.HALF_UP);
            
            // Clear CPQ fields AFTER reading to prevent feedback loop
            line.SBQQ__AdditionalDiscountAmount__c = null;
            line.SBQQ__Discount__c = null;
            line.SBQQ__SpecialPrice__c = null;
            
            if (lineShare > 0) {
                breakdown.add('Global (' + globalLabel + '): -' + lineShare.setScale(2) + ' ' + sym);
            }
            line.Discount_Breakdown__c = !breakdown.isEmpty() ? String.join(breakdown, ' | ') : 'No Discount';
        }
        
        update q;
        update lines;
    }
    
    private static Decimal toLocal(Decimal n, Decimal rate) {
        return (n * rate).setScale(2, System.RoundingMode.HALF_UP);
    }
    
    private class LineData {
        public SBQQ__QuoteLine__c line;
        public String family;
        public Decimal base;
        public Decimal net;
        public Decimal lineDisc;
        public Boolean isExempt;
        public List<String> breakdown;
        public Boolean skip;
    }
}