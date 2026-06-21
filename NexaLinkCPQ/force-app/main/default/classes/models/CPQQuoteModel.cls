/**
 * @description Domain model for general Quote operations.
 * Reorganized by a Junior Developer.
 */
public without sharing class CPQQuoteModel {
    
    /**
     * @description Retrieves quote header fields.
     */
    public static Map<String, Object> getQuoteHeader(String quoteId) {
        if (String.isBlank(quoteId)) return new Map<String, Object>();
        SBQQ__Quote__c q = [SELECT Id, Name, SBQQ__Status__c,
                                   SBQQ__Account__c, SBQQ__Account__r.Name,
                                   SBQQ__Opportunity2__c, CurrencyIsoCode
                            FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1];
        return new Map<String, Object>{
            'id'             => q.Id,
            'name'           => q.Name,
            'status'         => q.SBQQ__Status__c,
            'accountId'      => q.SBQQ__Account__c,
            'accountName'    => q.SBQQ__Account__r.Name,
            'opportunityId'  => q.SBQQ__Opportunity2__c,
            'currency'       => q.CurrencyIsoCode
        };
    }

    /**
     * @description Updates a quote's status field.
     */
    public static Map<String, Object> updateQuoteStatus(String quoteId, String status) {
        if (String.isBlank(quoteId)) throw new AuraHandledException('Quote ID is required');
        SBQQ__Quote__c q = [SELECT Id, SBQQ__Status__c FROM SBQQ__Quote__c WHERE Id = :quoteId LIMIT 1];
        q.SBQQ__Status__c = status;
        update q;
        return new Map<String, Object>{'success' => true, 'status' => status};
    }

    /**
     * @description Creates a new opportunity linked to an Account.
     */
    public static Map<String, String> createOpportunityForAccount(String accountId, String oppName, String closeDate, String currencyCode) {
        if (String.isBlank(accountId)) throw new AuraHandledException('Account ID is required');
        Id pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
        Opportunity opp = new Opportunity(
            AccountId = accountId,
            Name = oppName,
            StageName = 'Prospecting',
            CloseDate = Date.valueOf(closeDate),
            Pricebook2Id = pbId,
            CurrencyIsoCode = currencyCode
        );
        insert opp;
        return new Map<String, String>{ 'id' => opp.Id, 'name' => opp.Name };
    }

    /**
     * @description Retrieves the standard NexaLink template ID.
     */
    public static String getNexaLinkTemplateId() {
        List<SBQQ__QuoteTemplate__c> templates = [
            SELECT Id FROM SBQQ__QuoteTemplate__c
            WHERE Name = 'NexaLink Quote Template'
            LIMIT 1
        ];
        return templates.isEmpty() ? null : templates[0].Id;
    }
}
