/**
 * @description Controller for CPQ customer onboarding.
 * Delegating all logic to CPQCustomerOnboardingService.
 */
public without sharing class CPQCustomerOnboardingController {
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAccounts(String searchTerm) {
        return CPQCustomerOnboardingModel.getAccountsBySearch(searchTerm);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getOpportunities(String accountId) {
        return CPQCustomerOnboardingModel.getOpportunitiesByAccount(accountId);
    }

    @AuraEnabled
    public static Map<String, String> createNewCustomerQuote(Map<String, String> formData) {
        try {
            return CPQCustomerOnboardingModel.createNewCustomerQuote(formData);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, String> createQuote(String accountId, String opportunityId, String currencyCode) {
        try {
            return CPQCustomerOnboardingModel.createQuoteForExistingCustomer(accountId, opportunityId, currencyCode);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
