/**
 * @description Controller for general Quote actions.
 * Reorganized by a Junior Developer.
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
}
