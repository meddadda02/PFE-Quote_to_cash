/**
 * @description Controller for CPQ calculations and lines synchronization.
 */
public without sharing class CPQPricingController {

    @AuraEnabled
    public static Map<String, Object> syncProductsToQuote(String quoteId, String productsJson) {
        return CPQPricingModel.syncProductsToQuote(quoteId, productsJson);
    }

    @AuraEnabled
    public static Map<String, Object> clearAndAddAllBundles(String quoteId, String bundlesJson, String standaloneJson) {
        return CPQPricingModel.clearAndAddAllBundles(quoteId, bundlesJson, standaloneJson);
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> calculatePricing(String quoteId) {
        return CPQPricingModel.calculatePricing(quoteId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getQuoteLines(String quoteId) {
        return CPQPricingModel.getQuoteLines(quoteId);
    }

    @InvocableMethod(label='Calculate CPQ Pricing')
    public static void calculatePricingInvocable(List<Id> quoteIds) {
        CPQPricingModel.calculatePricingInvocable(quoteIds);
    }

    /**
     * Called from the LWC when the system detects a discount > 20%.
     * Submits the Quote through the Salesforce Approval Process so
     * the manager can approve or reject.
     * @param quoteId  Id of the SBQQ__Quote__c to submit
     * @param comments Optional comment shown to the approver
     */
    @AuraEnabled
    public static Map<String, Object> submitHighDiscountForApproval(String quoteId, String comments) {
        try {
            return CPQPricingModel.submitHighDiscountForApproval((Id) quoteId, comments);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> handleDiscountRejection(String quoteId) {
        try {
            return CPQPricingModel.handleDiscountRejection((Id) quoteId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}