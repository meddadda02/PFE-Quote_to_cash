public without sharing class CPQQuoteModel {

    // ID of the NexaLink SBQQ__QuoteTemplate__c used for all quote documents
    @TestVisible
    private static final String NEXALINK_TEMPLATE_ID = 'a0oQy000000LwKLIA0';

    public static Map<String, Object> getQuoteHeader(String quoteId) {
        if (String.isBlank(quoteId)) return new Map<String, Object>();
        SBQQ__Quote__c q = [SELECT Id, Name, SBQQ__Status__c,
                                   SBQQ__Account__c, SBQQ__Account__r.Name,
                                   SBQQ__Opportunity2__c, CurrencyIsoCode
                            FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1];
        return new Map<String, Object>{
            'id'           => q.Id,
            'name'         => q.Name,
            'status'       => q.SBQQ__Status__c,
            'accountId'    => q.SBQQ__Account__c,
            'accountName'  => q.SBQQ__Account__r.Name,
            'opportunityId'=> q.SBQQ__Opportunity2__c,
            'currency'     => q.CurrencyIsoCode
        };
    }

    public static Map<String, Object> updateQuoteStatus(String quoteId, String status) {
        if (String.isBlank(quoteId)) throw new AuraHandledException('Quote ID is required');
        SBQQ__Quote__c q = [SELECT Id, SBQQ__Status__c FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1];
        q.SBQQ__Status__c = status;
        update q;
        return new Map<String, Object>{'success' => true, 'status' => status};
    }

    public static Map<String, String> createOpportunityForAccount(String accountId, String oppName, String closeDate, String currencyCode) {
        if (String.isBlank(accountId)) throw new AuraHandledException('Account ID is required');
        Id pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
        Opportunity opp = new Opportunity(
            AccountId      = accountId,
            Name           = oppName,
            StageName      = 'Prospecting',
            CloseDate      = Date.valueOf(closeDate),
            Pricebook2Id   = pbId,
            CurrencyIsoCode = currencyCode
        );
        insert opp;
        return new Map<String, String>{ 'id' => opp.Id, 'name' => opp.Name };
    }

    public static String getNexaLinkTemplateId() {
        return NEXALINK_TEMPLATE_ID;
    }

    // ─── Generate Document ────────────────────────────────────────────────────

    /**
     * Generates the quote PDF using the NexaLink SBQQ__QuoteTemplate__c via CPQ's
     * REST API (SBQQ.QuoteDocumentSaver), saves it to Quote Files, and advances
     * the status Draft → Presented.
     *
     * Generation priority:
     *   1. CPQ REST API — uses the actual NexaLink template rendered server-side.
     *   2. CPQQuotePDF VF page — fallback if the CPQ API is unavailable or does
     *      not save to Files (e.g., Remote Site Setting not yet registered).
     *
     * IMPORTANT — callout ordering: ALL callouts (CPQ API, getContentAsPDF) must
     * precede any DML in the same transaction. The status update is therefore
     * deferred to after the generation block.
     */
    public static void generateDocument(String quoteId) {
        if (String.isBlank(quoteId)) throw new AuraHandledException('Quote ID is required');

        SBQQ__Quote__c q = [SELECT Id, Name, SBQQ__Status__c FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1];

        Id cvId;

        if (Test.isRunningTest()) {
            // Test context: skip all callouts — save a stub PDF directly
            cvId = savePdfAsContentVersion(quoteId, q.Name, Blob.valueOf('PDF_TEST_CONTENT'));
        } else {
            // 1. Try CPQ REST API using the NexaLink template (callout — no DML yet)
            cvId = generateViaCPQTemplate(quoteId);

            if (cvId == null) {
                // 2. Fallback: render CPQQuotePDF VF page (also a callout — no DML yet)
                //    This page renders the same NexaLink-branded template layout.
                PageReference pg = Page.CPQQuotePDF;
                pg.getParameters().put('id', quoteId);
                pg.getParameters().put('includeCoverPage', 'true');
                Blob pdfBlob = pg.getContentAsPDF();
                if (pdfBlob != null && pdfBlob.size() > 0) {
                    cvId = savePdfAsContentVersion(quoteId, q.Name, pdfBlob);
                }
            }
        }

        // DML: advance Draft → Presented and ensure Cover Page is included — executed AFTER all callouts ✓
        SBQQ__Quote__c quoteToUpdate = new SBQQ__Quote__c(Id = q.Id, Include_Cover_Page__c = true);
        if (q.SBQQ__Status__c == 'Draft') {
            quoteToUpdate.SBQQ__Status__c = 'Presented';
        }
        update quoteToUpdate;

        if (cvId == null) {
            throw new AuraHandledException('PDF generation failed. Verify the CPQQuotePDF Visualforce page is deployed and accessible.');
        }
    }

    /**
     * Calls CPQ's SBQQ.QuoteDocumentSaver REST endpoint to generate the quote
     * document server-side using the NexaLink SBQQ__QuoteTemplate__c.
     *
     * Strategy:
     *   a) Snapshot ContentVersions already linked to the quote.
     *   b) POST to /services/apexrest/SBQQ/ServiceRouter.
     *   c) If the response contains a documentId, resolve it to a ContentVersion.
     *   d) Otherwise, detect any NEW PDF ContentVersion that appeared after the call.
     *   e) Return null on any failure so the caller falls back to the VF page.
     *
     * Prerequisite: the org URL must be registered in Remote Site Settings
     * (NexaLink_CPQ_Self — deployed alongside this class).
     */
    @TestVisible
    private static Id generateViaCPQTemplate(String quoteId) {
        // Snapshot existing PDF versions so we can detect what CPQ newly saves
        Set<Id> existingVersionIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :quoteId AND ContentDocument.FileType = 'PDF'
        ]) {
            if (cdl.ContentDocument.LatestPublishedVersionId != null) {
                existingVersionIds.add(cdl.ContentDocument.LatestPublishedVersionId);
            }
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/apexrest/SBQQ/ServiceRouter');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000);

        String model = JSON.serialize(new Map<String, Object>{
            'quoteId'          => quoteId,
            'templateId'       => NEXALINK_TEMPLATE_ID,
            'outputFormat'     => 'PDF',
            'deliveryMethodId' => null,
            'defaultTemplate'  => false,
            'chunked'          => false
        });
        req.setBody(JSON.serialize(new Map<String, Object>{
            'saver' => 'SBQQ.QuoteDocumentSaver',
            'model' => model
        }));

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (CalloutException e) {
            System.debug(LoggingLevel.WARN, 'CPQ template API unavailable (check Remote Site Settings): ' + e.getMessage());
            return null;
        }

        if (res.getStatusCode() != 200) {
            System.debug(LoggingLevel.WARN, 'CPQ API returned HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            return null;
        }

        // Parse documentId from response (CPQ returns it when the document is saved to Files)
        try {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String docId = (String) result.get('documentId');
            if (String.isNotBlank(docId)) {
                List<ContentDocument> cds = [
                    SELECT LatestPublishedVersionId FROM ContentDocument WHERE Id = :docId LIMIT 1
                ];
                if (!cds.isEmpty()) return cds[0].LatestPublishedVersionId;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'CPQ response parse error: ' + e.getMessage());
        }

        // Detect any newly saved PDF that CPQ linked to the quote
        for (ContentDocumentLink cdl : [
            SELECT ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :quoteId
            AND ContentDocument.FileType = 'PDF'
            AND ContentDocument.LatestPublishedVersionId NOT IN :existingVersionIds
            ORDER BY ContentDocument.CreatedDate DESC LIMIT 1
        ]) {
            return cdl.ContentDocument.LatestPublishedVersionId;
        }

        return null;  // CPQ did not save to Files — caller will use VF page fallback
    }

    // ─── Send for Signature ───────────────────────────────────────────────────

    /**
     * Generates the Quote PDF if not already in Files, then sends it via DocuSign
     * for electronic signature.
     *
     * Path A — PDF already exists in Quote Files:
     *   Runs synchronously. Order: SOQL → dfsle callout → DML. ✓
     *
     * Path B — No PDF in Quote Files:
     *   PageReference.getContentAsPDF() must come BEFORE any DML (it is an
     *   implicit callout; external callouts cannot follow DML in the same txn).
     *   After saving the PDF (DML), the DocuSign send is delegated to
     *   DocuSignSendQueueable which starts a fresh transaction (SOQL → callout → DML).
     */
    public static void sendQuoteForSignature(String quoteId) {
        if (String.isBlank(quoteId)) throw new AuraHandledException('Quote ID is required');

        SBQQ__Quote__c q = [
            SELECT Id, Name, SBQQ__Status__c, SBQQ__Opportunity2__c, DocuSign_Envelope_Id__c
            FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1
        ];

        if (String.isNotBlank(q.DocuSign_Envelope_Id__c)) {
            throw new AuraHandledException('A DocuSign envelope already exists for this quote. Void it before sending a new one.');
        }
        if (String.isBlank(q.SBQQ__Opportunity2__c)) {
            throw new AuraHandledException('Quote has no linked Opportunity. Link one before sending for signature.');
        }

        List<OpportunityContactRole> roles = [
            SELECT ContactId, Contact.Name, Contact.Email
            FROM OpportunityContactRole
            WHERE OpportunityId = :q.SBQQ__Opportunity2__c
            AND Contact.Email != null
            ORDER BY IsPrimary DESC LIMIT 1
        ];
        if (roles.isEmpty()) {
            throw new AuraHandledException('No contact with an email found on the Opportunity. Add a Contact Role first.');
        }

        // Always generate a fresh PDF version to ensure the latest layout (cover page and signature fixes) is used
        Blob pdfBlob;
        if (Test.isRunningTest()) {
            pdfBlob = Blob.valueOf('PDF_TEST_CONTENT');
        } else {
            // Try CPQ REST API first using the NexaLink template
            Id templateCvId = generateViaCPQTemplate(quoteId);
            if (templateCvId != null) {
                // CPQ API succeeded — use that version directly
                // DML block (after the callout is complete)
                SBQQ__Quote__c quoteToUpdate = new SBQQ__Quote__c(Id = q.Id, Include_Cover_Page__c = true);
                if (q.SBQQ__Status__c == 'Draft') {
                    quoteToUpdate.SBQQ__Status__c = 'Presented';
                }
                update quoteToUpdate;
                System.enqueueJob(new DocuSignSendQueueable(
                    quoteId, templateCvId,
                    roles[0].Contact.Name, roles[0].Contact.Email, roles[0].ContactId
                ));
                return;
            }
            // Fallback: render CPQQuotePDF VF page (same NexaLink-branded layout)
            PageReference pg = Page.CPQQuotePDF;
            pg.getParameters().put('id', quoteId);
            pg.getParameters().put('includeCoverPage', 'true');
            pdfBlob = pg.getContentAsPDF();
        }

        // DML block (after the callout is complete)
        SBQQ__Quote__c quoteToUpdate = new SBQQ__Quote__c(Id = q.Id, Include_Cover_Page__c = true);
        if (q.SBQQ__Status__c == 'Draft') {
            quoteToUpdate.SBQQ__Status__c = 'Presented';
        }
        update quoteToUpdate;

        Id cvId = savePdfAsContentVersion(quoteId, q.Name, pdfBlob);

        // Enqueue DocuSign send — fresh transaction avoids DML-before-callout
        System.enqueueJob(new DocuSignSendQueueable(
            quoteId, cvId,
            roles[0].Contact.Name, roles[0].Contact.Email, roles[0].ContactId
        ));
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    /** Returns the LatestPublishedVersionId of the most-recently-added PDF in the Quote's Files, or null. */
    private static Id findLatestPdfVersionId(String quoteId) {
        for (ContentDocumentLink cdl : [
            SELECT ContentDocument.LatestPublishedVersionId,
                   ContentDocument.FileType,
                   ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :quoteId
            AND ContentDocument.FileType = 'PDF'
            ORDER BY ContentDocument.CreatedDate DESC LIMIT 1
        ]) {
            return cdl.ContentDocument.LatestPublishedVersionId;
        }
        return null;
    }

    /** Inserts a ContentVersion and links it to the Quote. Returns the ContentVersion Id. */
    @TestVisible
    private static Id savePdfAsContentVersion(String quoteId, String quoteName, Blob pdfBlob) {
        String fileName = 'Quote_' + quoteName.replaceAll('[^a-zA-Z0-9_\\-]', '_');
        ContentVersion cv = new ContentVersion(
            Title          = fileName,
            PathOnClient   = fileName + '.pdf',
            VersionData    = pdfBlob,
            IsMajorVersion = true
        );
        insert cv;

        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId    = quoteId,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        return cv.Id;
    }

    /**
     * Sends the Quote PDF to the client via DocuSign and stores the envelope ID.
     * SOQL → callout → DML — valid transaction order. Must NOT be preceded by DML in the caller.
     */
    @TestVisible
    private static void sendViaDocuSign(SBQQ__Quote__c q, String contactName, String contactEmail, Id contactId, Id cvId) {
        ContentVersion cv = [
            SELECT Id, Title, FileExtension, FileType, ContentSize, ContentModifiedDate
            FROM ContentVersion WHERE Id = :cvId LIMIT 1
        ];

        // Build recipient and tabs — pure object construction, safe in any context
        dfsle.Entity sourceEntity = new dfsle.Entity(q.Id);
        dfsle.Recipient recipient = dfsle.Recipient.fromSource(
            contactName, contactEmail, null, 'Signer 1', new dfsle.Entity(contactId)
        );
        recipient = recipient.withTabs(buildSignatureTabs());

        // Skip actual DocuSign send in test context (dfsle callout not mockable)
        if (Test.isRunningTest()) {
            update new SBQQ__Quote__c(Id = q.Id, DocuSign_Envelope_Id__c = 'TEST-ENVELOPE-ID');
            return;
        }

        dfsle.Envelope envelope = dfsle.EnvelopeService.getEmptyEnvelope(sourceEntity);
        envelope = envelope.withRecipients(new List<dfsle.Recipient>{ recipient });
        envelope = envelope.withDocuments(new List<dfsle.Document>{ dfsle.Document.fromFile(cv) });
        envelope = dfsle.EnvelopeService.sendEnvelope(envelope, true);

        update new SBQQ__Quote__c(Id = q.Id, DocuSign_Envelope_Id__c = String.valueOf(envelope.id));
    }

    /**
     * Builds the three DocuSign anchor tabs that correspond to the invisible anchor
     * text embedded in CPQQuotePDF.page (\s1\, \d1\, \n1\).
     */
    @TestVisible
    private static List<dfsle.Tab> buildSignatureTabs() {
        return new List<dfsle.Tab>{
            new dfsle.SignHereTab().withAnchor(new dfsle.Tab.Anchor('\\s1\\')),
            new dfsle.DateSignedTab().withAnchor(new dfsle.Tab.Anchor('\\d1\\')),
            new dfsle.FullNameTab().withAnchor(new dfsle.Tab.Anchor('\\n1\\'))
        };
    }
}
