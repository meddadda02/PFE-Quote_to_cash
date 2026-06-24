/**
 * @description Domain model for CPQ Order and Contract operations.
 * Reorganized by a Junior Developer.
 */
public without sharing class CPQOrderContractModel {
    
    /**
     * @description Marks a CPQ Quote as Ordered (triggers CPQ background automation).
     */
    public static Map<String, Object> markQuoteOrdered(String quoteId) {
        if (String.isBlank(quoteId)) throw new AuraHandledException('Quote ID is required');
        SBQQ__Quote__c q = [SELECT Id, SBQQ__Status__c, SBQQ__Ordered__c, SBQQ__Primary__c, SBQQ__Opportunity2__c, SBQQ__PricebookId__c 
                            FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1];
        
        if (q.SBQQ__Primary__c != true) {
            throw new AuraHandledException('Only the Primary quote can be ordered. Please check the "Primary" checkbox on the Quote record first.');
        }

        // Block quotes that are waiting for approval
        List<String> blockedStatuses = new List<String>{'Needs Review', 'In Review'};
        if (blockedStatuses.contains(q.SBQQ__Status__c)) {
            throw new AuraHandledException('This quote is pending approval (' + q.SBQQ__Status__c + '). Wait for manager approval before ordering.');
        }

        Integer lineCount = [SELECT count() FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :quoteId];
        if (lineCount == 0) {
            throw new AuraHandledException('Cannot order a quote with no lines. Please add products first.');
        }

        // Auto-advance Draft → Presented in a separate DML so CPQ sees the status BEFORE ordering
        if (q.SBQQ__Status__c == 'Draft') {
            q.SBQQ__Status__c = 'Presented';
            update q;
            q = [SELECT Id, SBQQ__Status__c, SBQQ__Ordered__c, SBQQ__Primary__c,
                        SBQQ__Opportunity2__c, SBQQ__PricebookId__c
                 FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1];
        }

        q.SBQQ__Ordered__c = true;
        try {
            update q;
        } catch (Exception ex) {
            // Catch ALL exception types including AuraHandledException thrown by CPQ triggers
            throw new AuraHandledException('CPQ ordering failed: ' + ex.getMessage()
                + ' — Verify: Account has BillingCountry, Opportunity has a Pricebook, Quote has lines.');
        }

        List<Order> orders = [SELECT Id, OrderNumber FROM Order WHERE SBQQ__Quote__c = :quoteId ORDER BY CreatedDate DESC LIMIT 1];
        Map<String, Object> result = new Map<String, Object>{'success' => true};
        if (!orders.isEmpty()) {
            result.put('orderId', orders[0].Id);
            result.put('orderNumber', orders[0].OrderNumber);
        }
        return result;
    }

    /**
     * @description Marks an Order as Contracted (triggers CPQ background automation).
     */
    public static Map<String, Object> markOrderContracted(String orderId) {
        if (String.isBlank(orderId)) throw new AuraHandledException('Order ID is required');
        Order o = [SELECT Id, SBQQ__Contracted__c, SBQQ__Quote__c, Status FROM Order WHERE Id = :orderId LIMIT 1];
        if (o.SBQQ__Quote__c == null) throw new AuraHandledException('Order is not linked to a CPQ Quote. Contract cannot be generated.');
        
        if (o.Status != 'Activated') {
            throw new AuraHandledException('The Order must be "Activated" before it can be marked as Contracted. Current status: ' + o.Status);
        }
        if (o.SBQQ__Contracted__c == true) return new Map<String, Object>{'success' => true, 'message' => 'Order is already contracted'};
        
        o.SBQQ__Contracted__c = true;
        update o; 
        
        List<Contract> contracts = [SELECT Id, ContractNumber, Status FROM Contract WHERE SBQQ__Order__c = :orderId ORDER BY CreatedDate DESC LIMIT 1];
        Map<String, Object> result = new Map<String, Object>{'success' => true};
        if (!contracts.isEmpty()) {
            result.put('contractId', contracts[0].Id);
            result.put('contractNumber', contracts[0].ContractNumber);
            result.put('contractStatus', contracts[0].Status);
        }
        return result;
    }

    /**
     * @description Retrieves orders created for a quote.
     */
    public static List<Map<String, Object>> getOrdersForQuote(String quoteId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (String.isBlank(quoteId)) return result;
        for (Order o : [SELECT Id, OrderNumber, Status, SBQQ__Contracted__c, TotalAmount, CurrencyIsoCode, CreatedDate
                        FROM Order WHERE SBQQ__Quote__c = :quoteId ORDER BY CreatedDate DESC LIMIT 10]) {
            result.add(new Map<String, Object>{
                'id' => o.Id, 
                'orderNumber' => o.OrderNumber, 
                'status' => o.Status,
                'contracted' => o.SBQQ__Contracted__c, 
                'total' => o.TotalAmount,
                'currency' => o.CurrencyIsoCode, 
                'createdDate' => o.CreatedDate
            });
        }
        return result;
    }

    /**
     * @description Retrieves order details for a header.
     */
    public static Map<String, Object> getOrderHeader(String orderId) {
        if (String.isBlank(orderId)) return new Map<String, Object>();
        Order o = [SELECT Id, OrderNumber, Status, SBQQ__Contracted__c, TotalAmount, CurrencyIsoCode 
                   FROM Order WHERE Id = :orderId LIMIT 1];
        return new Map<String, Object>{
            'id' => o.Id,
            'orderNumber' => o.OrderNumber,
            'status' => o.Status,
            'contracted' => o.SBQQ__Contracted__c,
            'total' => o.TotalAmount,
            'currency' => o.CurrencyIsoCode
        };
    }

    /**
     * @description Retrieves line items for an order.
     */
    public static List<Map<String, Object>> getOrderLines(String orderId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (String.isBlank(orderId)) return result;
        for (OrderItem oi : [SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                                    Product2.SBQQ__ChargeType__c, Quantity, UnitPrice, TotalPrice
                             FROM OrderItem WHERE OrderId = :orderId ORDER BY CreatedDate ASC]) {
            result.add(new Map<String, Object>{
                'id'          => oi.Id,
                'productId'   => oi.Product2Id,
                'name'        => oi.Product2 != null ? oi.Product2.Name : '',
                'productCode' => oi.Product2 != null ? oi.Product2.ProductCode : '',
                'chargeType'  => oi.Product2 != null ? oi.Product2.SBQQ__ChargeType__c : '',
                'quantity'    => oi.Quantity,
                'unitPrice'   => oi.UnitPrice,
                'totalPrice'  => oi.TotalPrice
            });
        }
        return result;
    }

    /**
     * @description Updates an order status field (e.g. to Active).
     */
    public static Map<String, Object> updateOrderStatus(String orderId, String status) {
        if (String.isBlank(orderId)) throw new AuraHandledException('Order ID is required');
        Order o = [SELECT Id, Status, EffectiveDate, Pricebook2Id, SBQQ__Quote__c, SBQQ__Quote__r.SBQQ__PricebookId__c 
                   FROM Order WHERE Id = :orderId LIMIT 1];
        
        if (o.Pricebook2Id == null && o.SBQQ__Quote__c != null && o.SBQQ__Quote__r.SBQQ__PricebookId__c != null) {
            o.Pricebook2Id = o.SBQQ__Quote__r.SBQQ__PricebookId__c;
        }

        if (o.EffectiveDate == null) {
            o.EffectiveDate = Date.today();
        }
        
        o.Status = status;
        update o;
        return new Map<String, Object>{'success' => true, 'status' => status};
    }

    /**
     * @description Retrieves contracts generated from a contracted Order.
     */
    public static List<Map<String, Object>> getContractsForOrder(String orderId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (String.isBlank(orderId)) return result;
        for (Contract c : [SELECT Id, ContractNumber, Status, StartDate, EndDate, AccountId, Account.Name, CurrencyIsoCode, CreatedDate
                           FROM Contract WHERE SBQQ__Order__c = :orderId ORDER BY CreatedDate DESC LIMIT 10]) {
            result.add(new Map<String, Object>{
                'id' => c.Id, 
                'contractNumber' => c.ContractNumber, 
                'status' => c.Status,
                'startDate' => c.StartDate, 
                'endDate' => c.EndDate,
                'accountName' => c.Account != null ? c.Account.Name : '',
                'currency' => c.CurrencyIsoCode, 
                'createdDate' => c.CreatedDate
            });
        }
        return result;
    }
}
