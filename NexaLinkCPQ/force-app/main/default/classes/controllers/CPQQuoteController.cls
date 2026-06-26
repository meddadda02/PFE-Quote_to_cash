/**
 * @description Controller for general Quote actions.
 * Reorganized by a Junior Developer.
 * [DocuSign integration added — generateAndSendForSignature]
 */
public without sharing class CPQQuoteController {
    
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getQuoteHeader(String quoteId) {
        return CPQQuoteModel.getQuoteHeader(quoteId);
    }

    @AuraEnabled
    public static Map<String, Object> updateQuoteStatus(String quoteId, String status) {
        try {
            return CPQQuoteModel.updateQuoteStatus(quoteId, status);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, String> createOpportunityForAccount(String accountId, String oppName, String closeDate, String currencyCode) {
        try {
            return CPQQuoteModel.createOpportunityForAccount(accountId, oppName, closeDate, currencyCode);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getNexaLinkTemplateId() {
        return CPQQuoteModel.getNexaLinkTemplateId();
    }

    @AuraEnabled
    public static void generateDocument(String quoteId) {
        // No try-catch — let AuraHandledException from model/CPQ propagate directly
        CPQQuoteModel.generateDocument(quoteId);
    }

    /**
     * generateAndSendEmail — enqueues CPQQuoteEmailQueueable directly from the
     * LWC "Generate & Send Email" button so the sales rep never leaves the
     * configurator. The Queueable generates the PDF via PageReference (async
     * context, no HTTP 500) and emails it to the primary contact.
     */
    @AuraEnabled
    public static void generateAndSendEmail(String quoteId) {
        if (String.isBlank(quoteId)) throw new AuraHandledException('Quote ID is required');
        try {
            System.enqueueJob(new CPQQuoteEmailQueueable(new Set<Id>{ quoteId }));
        } catch (Exception e) {
            throw new AuraHandledException('Failed to send email: ' + e.getMessage());
        }
    }

    /**
     * generateAndSendForSignature — sends the Quote's already-generated PDF
     * to the customer via DocuSign for electronic signature. Reuses
     * whatever PDF is already in the Quote's Files (generated via CPQ's
     * native "Generate Document" button), same precondition as
     * generateAndSendEmail. Runs synchronously — DocuSign's send is a
     * single quick callout, no Queueable needed.
     */
    @AuraEnabled
    public static void generateAndSendForSignature(String quoteId) {
        // No try-catch — let AuraHandledException propagate directly (re-wrapping loses the message)
        CPQQuoteModel.sendQuoteForSignature(quoteId);
    }
}