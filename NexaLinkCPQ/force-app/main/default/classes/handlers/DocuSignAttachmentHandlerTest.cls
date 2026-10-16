@isTest
private class DocuSignAttachmentHandlerTest {

    // ── Helpers ────────────────────────────────────────────────────────────────

    static SBQQ__Quote__c makeQuote() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Opportunity opp = new Opportunity(
            AccountId = acc.Id,
            Name      = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        SBQQ__Quote__c q = new SBQQ__Quote__c(
            SBQQ__Account__c      = acc.Id,
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Status__c       = 'Presented',
            SBQQ__Primary__c      = true
        );
        insert q;
        return q;
    }

    static Id makeContentDoc() {
        ContentVersion cv = new ContentVersion(
            Title          = 'Signed Quote PDF',
            PathOnClient   = 'signed.pdf',
            VersionData    = Blob.valueOf('SIGNED PDF CONTENT'),
            IsMajorVersion = true
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

    // Creates dfsle__Envelope__c + dfsle__EnvelopeStatus__c sharing the same docusignid.
    // Do NOT set dfsle__sourceid__c on EnvelopeStatus — it triggers CPQ_DocuSign_Post_Signature
    // flow which hits CPQ validation rules in test context.
    static Id[] makeEnvelopePair() {
        String guid = 'test-guid-' + Crypto.getRandomInteger();

        dfsle__Envelope__c env = new dfsle__Envelope__c(dfsle__docusignid__c = guid);
        insert env;

        dfsle__EnvelopeStatus__c status = new dfsle__EnvelopeStatus__c(
            dfsle__docusignid__c = guid,
            dfsle__Status__c     = 'Completed',
            dfsle__Completed__c  = DateTime.now()
        );
        insert status;

        return new Id[]{ env.Id, status.Id };   // [0]=envelopeId, [1]=statusId
    }

    static dfsle__Document__c makeDocRecord(Id envelopeId, Id contentDocId) {
        return new dfsle__Document__c(
            dfsle__Envelope__c      = envelopeId,
            dfsle__sourceid__c      = contentDocId,
            dfsle__isreplacement__c = false,
            dfsle__readonly__c      = false,
            dfsle__required__c      = false
        );
    }

    static DocuSignAttachmentHandler.Request makeRequest(Id statusId, Id quoteId) {
        DocuSignAttachmentHandler.Request req = new DocuSignAttachmentHandler.Request();
        req.envelopeStatusId = statusId;
        req.quoteId          = quoteId;
        return req;
    }

    // ── Document attachment tests ───────────────────────────────────────────────

    @isTest
    static void happyPath_createsLink() {
        SBQQ__Quote__c q = makeQuote();
        Id cdId          = makeContentDoc();
        Id[] pair        = makeEnvelopePair();
        insert makeDocRecord(pair[0], cdId);

        Test.startTest();
        DocuSignAttachmentHandler.attachSignedDocument(
            new List<DocuSignAttachmentHandler.Request>{ makeRequest(pair[1], q.Id) }
        );
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE ContentDocumentId = :cdId AND LinkedEntityId = :q.Id
        ], 'Should create exactly one ContentDocumentLink');
    }

    @isTest
    static void multipleDocs_attachesAll() {
        SBQQ__Quote__c q = makeQuote();
        Id cdId1         = makeContentDoc();
        Id cdId2         = makeContentDoc();
        Id[] pair        = makeEnvelopePair();
        insert makeDocRecord(pair[0], cdId1);
        insert makeDocRecord(pair[0], cdId2);

        Test.startTest();
        DocuSignAttachmentHandler.attachSignedDocument(
            new List<DocuSignAttachmentHandler.Request>{ makeRequest(pair[1], q.Id) }
        );
        Test.stopTest();

        System.assertEquals(2, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :q.Id AND ContentDocumentId IN (:cdId1, :cdId2)
        ], 'Should attach both signed PDF and certificate');
    }

    @isTest
    static void noDocs_returnsEarly() {
        SBQQ__Quote__c q = makeQuote();
        Id[] pair        = makeEnvelopePair();
        // No dfsle__Document__c records

        Test.startTest();
        DocuSignAttachmentHandler.attachSignedDocument(
            new List<DocuSignAttachmentHandler.Request>{ makeRequest(pair[1], q.Id) }
        );
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :q.Id],
            'No links should be created when no documents exist');
    }

    @isTest
    static void existingLink_noDuplicate() {
        SBQQ__Quote__c q = makeQuote();
        Id cdId          = makeContentDoc();
        Id[] pair        = makeEnvelopePair();
        insert makeDocRecord(pair[0], cdId);

        insert new ContentDocumentLink(
            ContentDocumentId = cdId, LinkedEntityId = q.Id,
            ShareType = 'V', Visibility = 'AllUsers'
        );

        Test.startTest();
        DocuSignAttachmentHandler.attachSignedDocument(
            new List<DocuSignAttachmentHandler.Request>{ makeRequest(pair[1], q.Id) }
        );
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE ContentDocumentId = :cdId AND LinkedEntityId = :q.Id
        ], 'Should not create a duplicate link');
    }

    @isTest
    static void invalidSourceId_skippedGracefully() {
        SBQQ__Quote__c q = makeQuote();
        Id[] pair        = makeEnvelopePair();

        insert new dfsle__Document__c(
            dfsle__Envelope__c      = pair[0],
            dfsle__sourceid__c      = q.Id,   // Quote ID, not a ContentDocument
            dfsle__isreplacement__c = false,
            dfsle__readonly__c      = false,
            dfsle__required__c      = false
        );

        Test.startTest();
        DocuSignAttachmentHandler.attachSignedDocument(
            new List<DocuSignAttachmentHandler.Request>{ makeRequest(pair[1], q.Id) }
        );
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :q.Id],
            'Non-ContentDocument sourceId should be skipped without throwing');
    }

    @isTest
    static void nullInputs_skippedGracefully() {
        DocuSignAttachmentHandler.Request req = new DocuSignAttachmentHandler.Request();
        req.envelopeStatusId = null;
        req.quoteId          = null;

        Test.startTest();
        DocuSignAttachmentHandler.attachSignedDocument(
            new List<DocuSignAttachmentHandler.Request>{ req }
        );
        Test.stopTest();

        System.assert(true, 'Null inputs should be handled gracefully');
    }

    @isTest
    static void noMatchingEnvelope_returnsEarly() {
        SBQQ__Quote__c q = makeQuote();
        dfsle__EnvelopeStatus__c orphanStatus = new dfsle__EnvelopeStatus__c(
            dfsle__docusignid__c = 'no-matching-envelope-guid',
            dfsle__Status__c     = 'Completed'
        );
        insert orphanStatus;

        Test.startTest();
        DocuSignAttachmentHandler.attachSignedDocument(
            new List<DocuSignAttachmentHandler.Request>{ makeRequest(orphanStatus.Id, q.Id) }
        );
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :q.Id],
            'No links when envelope record not found');
    }

    @isTest
    static void bulkRequests_processedAll() {
        SBQQ__Quote__c q1 = makeQuote();
        SBQQ__Quote__c q2 = makeQuote();
        Id cdId1          = makeContentDoc();
        Id cdId2          = makeContentDoc();
        Id[] pair1        = makeEnvelopePair();
        Id[] pair2        = makeEnvelopePair();
        insert makeDocRecord(pair1[0], cdId1);
        insert makeDocRecord(pair2[0], cdId2);

        Test.startTest();
        DocuSignAttachmentHandler.attachSignedDocument(new List<DocuSignAttachmentHandler.Request>{
            makeRequest(pair1[1], q1.Id),
            makeRequest(pair2[1], q2.Id)
        });
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM ContentDocumentLink
            WHERE ContentDocumentId = :cdId1 AND LinkedEntityId = :q1.Id], 'First request processed');
        System.assertEquals(1, [SELECT COUNT() FROM ContentDocumentLink
            WHERE ContentDocumentId = :cdId2 AND LinkedEntityId = :q2.Id], 'Second request processed');
    }

    // ── Post-signature Quote update tests ──────────────────────────────────────

    @isTest
    static void happyPath_quoteAcceptedWithDocuSignFields() {
        SBQQ__Quote__c q = makeQuote();
        Id cdId          = makeContentDoc();
        Id[] pair        = makeEnvelopePair();
        insert makeDocRecord(pair[0], cdId);

        Test.startTest();
        DocuSignAttachmentHandler.attachSignedDocument(
            new List<DocuSignAttachmentHandler.Request>{ makeRequest(pair[1], q.Id) }
        );
        Test.stopTest();

        // Verify document attached
        System.assertEquals(1, [SELECT COUNT() FROM ContentDocumentLink
            WHERE ContentDocumentId = :cdId AND LinkedEntityId = :q.Id],
            'Signed PDF should be linked to Quote');

        // Verify Quote status and DocuSign fields updated
        q = [SELECT SBQQ__Status__c, DocuSign_Envelope_Id__c,
                    DocuSign_Completed_Date__c, Signed_PDF_Document_Id__c
             FROM SBQQ__Quote__c WHERE Id = :q.Id];
        System.assertEquals('Accepted',  q.SBQQ__Status__c,      'Quote should be Accepted');
        System.assertNotEquals(null,     q.DocuSign_Envelope_Id__c,    'Envelope ID should be stored');
        System.assertNotEquals(null,     q.DocuSign_Completed_Date__c, 'Completed date should be stored');
        System.assertEquals(String.valueOf(cdId), q.Signed_PDF_Document_Id__c, 'Signed PDF document ID should be stored');
    }

    @isTest
    static void idempotent_alreadyAccepted_skips() {
        SBQQ__Quote__c q = makeQuote();
        Id cdId          = makeContentDoc();
        Id[] pair        = makeEnvelopePair();
        insert makeDocRecord(pair[0], cdId);

        // Pre-condition: simulate a previous completed webhook by marking Quote as Accepted.
        // Using Status=Accepted (not SBQQ__Ordered__c=true) because CPQ's managed trigger
        // blocks ordering without Quote Lines in test context.
        update new SBQQ__Quote__c(Id = q.Id, SBQQ__Status__c = 'Accepted');

        Test.startTest();
        DocuSignAttachmentHandler.attachSignedDocument(
            new List<DocuSignAttachmentHandler.Request>{ makeRequest(pair[1], q.Id) }
        );
        Test.stopTest();

        // Idempotent guard fired — no documents should have been attached
        System.assertEquals(0, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE ContentDocumentId = :cdId AND LinkedEntityId = :q.Id
        ], 'Second webhook should be ignored (idempotent guard)');
    }

    @isTest
    static void quoteAlreadyLinked_stillUpdatesStatus() {
        SBQQ__Quote__c q = makeQuote();
        Id cdId          = makeContentDoc();
        Id[] pair        = makeEnvelopePair();
        insert makeDocRecord(pair[0], cdId);

        // Pre-link the document (simulates a previous partial run)
        insert new ContentDocumentLink(
            ContentDocumentId = cdId, LinkedEntityId = q.Id,
            ShareType = 'V', Visibility = 'AllUsers'
        );

        Test.startTest();
        DocuSignAttachmentHandler.attachSignedDocument(
            new List<DocuSignAttachmentHandler.Request>{ makeRequest(pair[1], q.Id) }
        );
        Test.stopTest();

        // No duplicate link
        System.assertEquals(1, [SELECT COUNT() FROM ContentDocumentLink
            WHERE ContentDocumentId = :cdId AND LinkedEntityId = :q.Id],
            'Document should not be duplicated');

        // Quote should still be Accepted
        q = [SELECT SBQQ__Status__c FROM SBQQ__Quote__c WHERE Id = :q.Id];
        System.assertEquals('Accepted', q.SBQQ__Status__c,
            'Quote should be Accepted even when doc was already linked');
    }

    @isTest
    static void sendCompletionEmail_doesNotThrow() {
        SBQQ__Quote__c q = makeQuote();
        // Reload with relationship data so SBQQ__Account__r.Name is accessible
        q = [SELECT Id, Name, OwnerId, SBQQ__Primary__c, SBQQ__Status__c,
                    SBQQ__Ordered__c, SBQQ__Account__r.Name
             FROM SBQQ__Quote__c WHERE Id = :q.Id LIMIT 1];

        Test.startTest();
        DocuSignAttachmentHandler.sendCompletionEmail(q, DateTime.now());
        DocuSignAttachmentHandler.sendCompletionEmail(q, null); // null date path
        Test.stopTest();

        System.assert(true, 'sendCompletionEmail should complete without throwing');
    }
}
