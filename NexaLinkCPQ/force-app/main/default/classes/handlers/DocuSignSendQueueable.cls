/**
 * Sends a Quote PDF to a client via DocuSign in a fresh Apex transaction.
 * Called by CPQQuoteModel.sendQuoteForSignature when no PDF exists yet —
 * the PDF is generated + saved (DML) in the calling transaction, then this
 * Queueable runs in its own transaction: SOQL → callout → DML.
 * That order satisfies the Salesforce "no callout after uncommitted DML" rule.
 */
public without sharing class DocuSignSendQueueable implements Queueable, Database.AllowsCallouts {

    private final String quoteId;
    private final Id     contentVersionId;
    private final String contactName;
    private final String contactEmail;
    private final Id     contactId;

    public DocuSignSendQueueable(
        String quoteId,
        Id     contentVersionId,
        String contactName,
        String contactEmail,
        Id     contactId
    ) {
        this.quoteId          = quoteId;
        this.contentVersionId = contentVersionId;
        this.contactName      = contactName;
        this.contactEmail     = contactEmail;
        this.contactId        = contactId;
    }

    public void execute(QueueableContext ctx) {
        // Guard: abort if another send already completed between enqueue and execution
        SBQQ__Quote__c q = [
            SELECT Id, DocuSign_Envelope_Id__c
            FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1
        ];
        if (String.isNotBlank(q.DocuSign_Envelope_Id__c)) return;

        ContentVersion cv = [
            SELECT Id, Title, FileExtension, FileType, ContentSize, ContentModifiedDate
            FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1
        ];

        // Build recipient and tabs — pure object construction, safe in any context
        dfsle.Entity sourceEntity = new dfsle.Entity(q.Id);
        dfsle.Recipient recipient = dfsle.Recipient.fromSource(
            contactName, contactEmail, null, 'Signer 1', new dfsle.Entity(contactId)
        );
        recipient = recipient.withTabs(new List<dfsle.Tab>{
            new dfsle.SignHereTab().withAnchor(new dfsle.Tab.Anchor('\\s1\\')),
            new dfsle.DateSignedTab().withAnchor(new dfsle.Tab.Anchor('\\d1\\')),
            new dfsle.FullNameTab().withAnchor(new dfsle.Tab.Anchor('\\n1\\'))
        });

        // Allow tests to bypass the dfsle callout
        if (Test.isRunningTest()) {
            update new SBQQ__Quote__c(Id = q.Id, DocuSign_Envelope_Id__c = 'TEST-ENVELOPE-ID-ASYNC');
            return;
        }

        try {
            dfsle.Envelope envelope = dfsle.EnvelopeService.getEmptyEnvelope(sourceEntity);
            envelope = envelope.withRecipients(new List<dfsle.Recipient>{ recipient });
            envelope = envelope.withDocuments(new List<dfsle.Document>{ dfsle.Document.fromFile(cv) });
            envelope = dfsle.EnvelopeService.sendEnvelope(envelope, true);

            update new SBQQ__Quote__c(Id = q.Id, DocuSign_Envelope_Id__c = String.valueOf(envelope.id));
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'DocuSignSendQueueable.execute failed for Quote ' + quoteId + ': ' + ex.getMessage());
        }
    }
}
