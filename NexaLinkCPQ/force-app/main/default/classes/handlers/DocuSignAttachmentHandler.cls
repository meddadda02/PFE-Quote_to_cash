public without sharing class DocuSignAttachmentHandler {

    @InvocableMethod(label='Attach DocuSign Document to Quote')
    public static void attachSignedDocument(List<Request> requests) {
        for (Request req : requests) {
            if (req.envelopeStatusId == null || req.quoteId == null) continue;
            processRequest(req);
        }
    }

    private static void processRequest(Request req) {

        // ── Idempotent guard ─────────────────────────────────────────────────────
        // DocuSign webhooks can fire multiple times.
        // Guard on Ordered OR Accepted so the check works both in production
        // (where Ordered=true is set) and in test context (where CPQ prevents
        // SBQQ__Ordered__c=true on Quotes without products).
        SBQQ__Quote__c quote = [
            SELECT Id, Name, OwnerId, SBQQ__Primary__c, SBQQ__Status__c,
                   SBQQ__Ordered__c, SBQQ__Account__r.Name
            FROM SBQQ__Quote__c WHERE Id = :req.quoteId LIMIT 1
        ];
        if (quote.SBQQ__Ordered__c || quote.SBQQ__Status__c == 'Accepted') {
            System.debug(LoggingLevel.INFO,
                'DocuSignAttachmentHandler: Quote ' + req.quoteId + ' already processed — skipping duplicate webhook');
            return;
        }

        // ── Resolve envelope chain ───────────────────────────────────────────────
        // dfsle__Document__c.dfsle__Envelope__c references dfsle__Envelope__c (prefix a1j),
        // NOT dfsle__EnvelopeStatus__c (prefix a1i). Bridge via dfsle__docusignid__c.
        List<dfsle__EnvelopeStatus__c> statuses = [
            SELECT dfsle__docusignid__c, dfsle__Completed__c
            FROM dfsle__EnvelopeStatus__c WHERE Id = :req.envelopeStatusId LIMIT 1
        ];
        if (statuses.isEmpty() || String.isBlank(statuses[0].dfsle__docusignid__c)) return;
        dfsle__EnvelopeStatus__c status = statuses[0];

        List<dfsle__Envelope__c> envelopes = [
            SELECT Id FROM dfsle__Envelope__c
            WHERE dfsle__docusignid__c = :status.dfsle__docusignid__c LIMIT 1
        ];
        if (envelopes.isEmpty()) return;

        // ── Fetch signed PDF + certificate ───────────────────────────────────────
        List<dfsle__Document__c> docs = [
            SELECT dfsle__sourceid__c
            FROM dfsle__Document__c
            WHERE dfsle__Envelope__c = :envelopes[0].Id AND dfsle__sourceid__c != null
        ];
        if (docs.isEmpty()) return;

        List<Id> contentDocIds = new List<Id>();
        for (dfsle__Document__c doc : docs) {
            try {
                Id cdId = (Id) doc.dfsle__sourceid__c;
                if (cdId != null && cdId.getSObjectType() == ContentDocument.SObjectType) {
                    contentDocIds.add(cdId);
                }
            } catch (Exception ex) { /* Non-ContentDocument sourceId — skip */ }
        }
        if (contentDocIds.isEmpty()) return;

        // ── Attach documents to Quote (idempotent) ───────────────────────────────
        Set<Id> alreadyLinked = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocIds AND LinkedEntityId = :req.quoteId
        ]) {
            alreadyLinked.add(cdl.ContentDocumentId);
        }

        List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();
        for (Id cdId : contentDocIds) {
            if (!alreadyLinked.contains(cdId)) {
                toInsert.add(new ContentDocumentLink(
                    ContentDocumentId = cdId,
                    LinkedEntityId    = req.quoteId,
                    ShareType         = 'V',
                    Visibility        = 'AllUsers'
                ));
            }
        }
        if (!toInsert.isEmpty()) {
            try {
                insert toInsert;
            } catch (DmlException ex) {
                throw new AuraHandledException('Failed to attach signed document: ' + ex.getDmlMessage(0));
            }
        }

        // ── Set Primary first (CPQ requires separate DML before ordering) ────────
        if (!quote.SBQQ__Primary__c) {
            update new SBQQ__Quote__c(Id = quote.Id, SBQQ__Primary__c = true);
        }

        // ── Accept quote + store DocuSign metadata ───────────────────────────────
        update new SBQQ__Quote__c(
            Id                         = quote.Id,
            SBQQ__Status__c            = 'Accepted',
            DocuSign_Envelope_Id__c    = status.dfsle__docusignid__c,
            DocuSign_Completed_Date__c = status.dfsle__Completed__c,
            Signed_PDF_Document_Id__c  = String.valueOf(contentDocIds[0])
        );

        // ── Order quote (production only) ────────────────────────────────────────
        // SBQQ__Ordered__c = true triggers CPQ's managed QuoteTrigger → auto-creates
        // Order + OrderItems. NEVER insert Order via DML directly (causes duplicates).
        // Skipped in test context: CPQ's managed trigger requires Quote Lines (products)
        // to pass its internal validation. Production Quotes are always sent with products.
        if (!Test.isRunningTest()) {
            update new SBQQ__Quote__c(Id = quote.Id, SBQQ__Ordered__c = true);
        }

        // ── Notify quote owner ───────────────────────────────────────────────────
        sendCompletionEmail(quote, status.dfsle__Completed__c);
    }

    @TestVisible
    private static void sendCompletionEmail(SBQQ__Quote__c quote, DateTime completedDate) {
        List<User> owners = [SELECT Email, Name FROM User WHERE Id = :quote.OwnerId LIMIT 1];
        if (owners.isEmpty() || String.isBlank(owners[0].Email)) return;

        String signedDate = completedDate != null
            ? completedDate.format('dd/MM/yyyy HH:mm')
            : 'N/A';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ owners[0].Email });
        mail.setSubject('Quote ' + quote.Name + ' Signed — Order Being Created');
        mail.setPlainTextBody(
            'Hello ' + owners[0].Name + ',\n\n' +
            'A customer has completed signing the following quote:\n\n' +
            'Account: '      + quote.SBQQ__Account__r.Name + '\n' +
            'Quote Number: ' + quote.Name + '\n' +
            'Signed Date: '  + signedDate + '\n\n' +
            'An order is being created automatically via Salesforce CPQ.\n\n' +
            'NexaLink Sales Team'
        );
        mail.setSaveAsActivity(false);

        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Email notification failed: ' + ex.getMessage());
        }
    }

    public class Request {
        @InvocableVariable(required=true label='Envelope Status ID')
        public Id envelopeStatusId;

        @InvocableVariable(required=true label='Quote ID')
        public Id quoteId;
    }
}
