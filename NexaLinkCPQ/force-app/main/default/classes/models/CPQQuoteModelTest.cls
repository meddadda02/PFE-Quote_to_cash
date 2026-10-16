@isTest
private class CPQQuoteModelTest {

    // ── Test data ─────────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            AccountId = acc.Id,
            Name      = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Contact con = new Contact(
            AccountId  = acc.Id,
            FirstName  = 'Test',
            LastName   = 'Contact',
            Email      = 'test.contact@nexalink-test.com'
        );
        insert con;

        insert new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId     = con.Id,
            IsPrimary     = true
        );

        SBQQ__Quote__c q = new SBQQ__Quote__c(
            SBQQ__Account__c      = acc.Id,
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Status__c       = 'Draft'
        );
        insert q;
    }

    static SBQQ__Quote__c getQuote() {
        return [SELECT Id, Name, SBQQ__Status__c, SBQQ__Opportunity2__c, DocuSign_Envelope_Id__c
                FROM SBQQ__Quote__c LIMIT 1];
    }

    static Id attachPdfToQuote(Id quoteId) {
        ContentVersion cv = new ContentVersion(
            Title          = 'Quote_Test',
            PathOnClient   = 'Quote_Test.pdf',
            VersionData    = Blob.valueOf('PDF CONTENT'),
            IsMajorVersion = true
        );
        insert cv;
        Id cdId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = cdId, LinkedEntityId = quoteId,
            ShareType = 'V', Visibility = 'AllUsers'
        );
        return cv.Id;
    }

    // ── getQuoteHeader ────────────────────────────────────────────────────────

    @isTest
    static void getQuoteHeader_blankId_returnsEmpty() {
        Test.startTest();
        Map<String, Object> result = CPQQuoteModel.getQuoteHeader('');
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Blank ID should return empty map');
    }

    @isTest
    static void getQuoteHeader_validId_returnsData() {
        SBQQ__Quote__c q = getQuote();

        Test.startTest();
        Map<String, Object> result = CPQQuoteModel.getQuoteHeader(q.Id);
        Test.stopTest();

        System.assertEquals(q.Id, result.get('id'), 'id should match quote Id');
        System.assertNotEquals(null, result.get('name'), 'name should be populated');
        System.assertEquals('Draft', result.get('status'), 'status should be Draft');
    }

    // ── updateQuoteStatus ─────────────────────────────────────────────────────

    @isTest
    static void updateQuoteStatus_updatesStatus() {
        SBQQ__Quote__c q = getQuote();

        Test.startTest();
        Map<String, Object> result = CPQQuoteModel.updateQuoteStatus(q.Id, 'Presented');
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        q = getQuote();
        System.assertEquals('Presented', q.SBQQ__Status__c);
    }

    @isTest
    static void updateQuoteStatus_blankId_throws() {
        try {
            CPQQuoteModel.updateQuoteStatus('', 'Presented');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true, 'AuraHandledException thrown as expected');
        }
    }

    // ── getNexaLinkTemplateId ─────────────────────────────────────────────────

    @isTest
    static void getNexaLinkTemplateId_returnsExpectedId() {
        Test.startTest();
        String templateId = CPQQuoteModel.getNexaLinkTemplateId();
        Test.stopTest();
        System.assertEquals('a0oQy000000LwKLIA0', templateId, 'Should return the correct NexaLink template Id');
    }

    // ── generateDocument ──────────────────────────────────────────────────────

    @isTest
    static void generateDocument_advancesToPresented() {
        SBQQ__Quote__c q = getQuote();
        System.assertEquals('Draft', q.SBQQ__Status__c);

        Test.startTest();
        CPQQuoteModel.generateDocument(q.Id);
        Test.stopTest();

        q = getQuote();
        System.assertEquals('Presented', q.SBQQ__Status__c, 'Should advance Draft → Presented');
    }

    @isTest
    static void generateDocument_createsPdfInFiles() {
        SBQQ__Quote__c q = getQuote();

        Test.startTest();
        CPQQuoteModel.generateDocument(q.Id);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :q.Id AND ContentDocument.FileType = 'PDF'
        ];
        System.assertEquals(1, links.size(), 'Should create one PDF in Quote Files');
    }

    @isTest
    static void generateDocument_blankId_throws() {
        try {
            CPQQuoteModel.generateDocument('');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true, 'AuraHandledException thrown as expected');
        }
    }

    // ── sendQuoteForSignature — Path A (PDF exists) ───────────────────────────

    @isTest
    static void sendForSignature_pathA_existingPdf_setsEnvelopeId() {
        SBQQ__Quote__c q = getQuote();
        attachPdfToQuote(q.Id);

        Test.startTest();
        CPQQuoteModel.sendQuoteForSignature(q.Id);
        Test.stopTest();

        q = getQuote();
        System.assertEquals('TEST-ENVELOPE-ID-ASYNC', q.DocuSign_Envelope_Id__c,
            'Path A: envelope ID should be set after synchronous send');
    }

    @isTest
    static void sendForSignature_pathA_duplicateEnvelope_throws() {
        SBQQ__Quote__c q = getQuote();
        attachPdfToQuote(q.Id);
        update new SBQQ__Quote__c(Id = q.Id, DocuSign_Envelope_Id__c = 'EXISTING-ENV-123');

        try {
            CPQQuoteModel.sendQuoteForSignature(q.Id);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true, 'AuraHandledException thrown as expected for duplicate envelope');
        }
    }

    @isTest
    static void sendForSignature_pathA_noOpportunity_throws() {
        Account acc = new Account(Name = 'No Opp Account');
        insert acc;
        SBQQ__Quote__c q2 = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Status__c  = 'Presented'
        );
        insert q2;
        attachPdfToQuote(q2.Id);

        try {
            CPQQuoteModel.sendQuoteForSignature(q2.Id);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true, 'AuraHandledException thrown as expected for missing Opportunity');
        }
    }

    @isTest
    static void sendForSignature_pathA_noContactRole_throws() {
        Account acc = new Account(Name = 'No Contact Account');
        insert acc;
        Opportunity opp = new Opportunity(
            AccountId = acc.Id, Name = 'No Contact Opp',
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        SBQQ__Quote__c q2 = new SBQQ__Quote__c(
            SBQQ__Account__c      = acc.Id,
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Status__c       = 'Presented'
        );
        insert q2;
        attachPdfToQuote(q2.Id);

        try {
            CPQQuoteModel.sendQuoteForSignature(q2.Id);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true, 'AuraHandledException thrown as expected for missing contact');
        }
    }

    // ── sendQuoteForSignature — Path B (no PDF, auto-generate) ───────────────

    @isTest
    static void sendForSignature_pathB_noPdf_generatesPdfAndEnqueues() {
        SBQQ__Quote__c q = getQuote();
        // No PDF in Files

        Test.startTest();
        CPQQuoteModel.sendQuoteForSignature(q.Id);
        Test.stopTest();

        // PDF should now exist in Quote Files
        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :q.Id AND ContentDocument.FileType = 'PDF'
        ];
        System.assertEquals(1, links.size(), 'Path B: should generate and save PDF in Quote Files');

        // Queueable should have been enqueued (runs async; Test.stopTest() flushes it)
        q = getQuote();
        System.assertEquals('TEST-ENVELOPE-ID-ASYNC', q.DocuSign_Envelope_Id__c,
            'Path B: Queueable should set envelope ID after async send');
    }

    @isTest
    static void sendForSignature_pathB_advancesToPresented() {
        SBQQ__Quote__c q = getQuote();
        System.assertEquals('Draft', q.SBQQ__Status__c);

        Test.startTest();
        CPQQuoteModel.sendQuoteForSignature(q.Id);
        Test.stopTest();

        q = getQuote();
        System.assertEquals('Presented', q.SBQQ__Status__c, 'Path B: should advance Draft → Presented');
    }

    @isTest
    static void sendForSignature_pathB_alreadyPresented_noStatusChange() {
        SBQQ__Quote__c q = getQuote();
        update new SBQQ__Quote__c(Id = q.Id, SBQQ__Status__c = 'Presented');

        Test.startTest();
        CPQQuoteModel.sendQuoteForSignature(q.Id);
        Test.stopTest();

        q = getQuote();
        System.assertEquals('Presented', q.SBQQ__Status__c, 'Should remain Presented');
    }

    // ── DocuSignSendQueueable ─────────────────────────────────────────────────

    @isTest
    static void queueable_execute_setsEnvelopeId() {
        SBQQ__Quote__c q = getQuote();
        Id cvId = attachPdfToQuote(q.Id);
        Contact con = [SELECT Id, Name, Email FROM Contact LIMIT 1];

        Test.startTest();
        System.enqueueJob(new DocuSignSendQueueable(q.Id, cvId, con.Name, con.Email, con.Id));
        Test.stopTest();

        q = getQuote();
        System.assertEquals('TEST-ENVELOPE-ID-ASYNC', q.DocuSign_Envelope_Id__c,
            'Queueable should set envelope ID');
    }

    @isTest
    static void queueable_execute_alreadySent_skips() {
        SBQQ__Quote__c q = getQuote();
        Id cvId = attachPdfToQuote(q.Id);
        update new SBQQ__Quote__c(Id = q.Id, DocuSign_Envelope_Id__c = 'ALREADY-SENT');

        Contact con = [SELECT Id, Name, Email FROM Contact LIMIT 1];

        Test.startTest();
        System.enqueueJob(new DocuSignSendQueueable(q.Id, cvId, con.Name, con.Email, con.Id));
        Test.stopTest();

        q = getQuote();
        System.assertEquals('ALREADY-SENT', q.DocuSign_Envelope_Id__c,
            'Should not overwrite existing envelope ID');
    }

    // ── buildSignatureTabs (private helper, tested via @TestVisible) ──────────

    @isTest
    static void buildSignatureTabs_returnsThreeTabs() {
        Test.startTest();
        List<dfsle.Tab> tabs = CPQQuoteModel.buildSignatureTabs();
        Test.stopTest();

        System.assertEquals(3, tabs.size(), 'Should return SignHere, DateSigned, and FullName tabs');
        System.assertNotEquals(null, tabs[0], 'SignHere tab should not be null');
        System.assertNotEquals(null, tabs[1], 'DateSigned tab should not be null');
        System.assertNotEquals(null, tabs[2], 'FullName tab should not be null');
    }

    // ── savePdfAsContentVersion (private helper, tested via @TestVisible) ─────

    @isTest
    static void savePdfAsContentVersion_linksToQuote() {
        SBQQ__Quote__c q = getQuote();
        Blob pdf = Blob.valueOf('FAKE PDF BYTES');

        Test.startTest();
        Id cvId = CPQQuoteModel.savePdfAsContentVersion(q.Id, 'Test Quote', pdf);
        Test.stopTest();

        System.assertNotEquals(null, cvId, 'Should return ContentVersion Id');

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :q.Id AND ContentDocument.FileType = 'PDF'
        ];
        System.assertEquals(1, links.size(), 'Should link the PDF to the Quote');
    }
}
