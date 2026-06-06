/**
 * @description Model class handling customer onboarding and initial quote setup logic.
 * Written by a Junior Developer following MVC architecture.
 */
public without sharing class CPQCustomerOnboardingModel {
    
    /**
     * @description Searches for accounts matching the search term.
     */
    public static List<Map<String, Object>> getAccountsBySearch(String searchTerm) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        String queryTerm = '%' + (searchTerm == null ? '' : searchTerm) + '%';
        for (Account acc : [SELECT Id, Name, BillingCountry FROM Account WHERE Name LIKE :queryTerm LIMIT 10]) {
            result.add(new Map<String, Object>{
                'id' => acc.Id, 
                'name' => acc.Name, 
                'country' => acc.BillingCountry
            });
        }
        return result;
    }

    /**
     * @description Retrieves open opportunities associated with a specific account.
     */
    public static List<Map<String, Object>> getOpportunitiesByAccount(String accountId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (String.isBlank(accountId)) return result;
        for (Opportunity opp : [SELECT Id, Name, StageName, CurrencyIsoCode, Pricebook2Id 
                                FROM Opportunity 
                                WHERE AccountId = :accountId AND IsClosed = false LIMIT 10]) {
            result.add(new Map<String, Object>{
                'id' => opp.Id, 
                'name' => opp.Name, 
                'stage' => opp.StageName, 
                'currency' => opp.CurrencyIsoCode, 
                'pricebookId' => opp.Pricebook2Id
            });
        }
        return result;
    }

    /**
     * @description Creates a new Account, Contact, Opportunity, Contact Role, and primary Quote in one transaction.
     */
    public static Map<String, String> createNewCustomerQuote(Map<String, String> formData) {
        String customerType = formData.get('customerType'); 
        String firstName = formData.get('firstName');
        String lastName = formData.get('lastName');
        String email = formData.get('email');
        String phone = formData.get('phone');
        String companyName = formData.get('companyName');
        String opportunityName = formData.get('opportunityName');
        String currencyCode = formData.get('currencyCode');
        String country = formData.get('country');
        
        Boolean isNewCustomer = formData.get('isNewCustomer') == 'true';
        Boolean isStudent = formData.get('isStudent') == 'true';
        Boolean isTelecomEmployee = formData.get('isTelecomEmployee') == 'true';
        Boolean isExistingCustomer = formData.get('isExistingCustomer') == 'true';

        Account acc = new Account(
            CurrencyIsoCode = currencyCode,
            BillingCountry = country,
            Phone = phone,
            Is_New_Customer__c = isNewCustomer,
            Is_Student__c = isStudent,
            Is_Telecom_Employee__c = isTelecomEmployee,
            Is_Existing_Customer__c = isExistingCustomer
        );
        if (customerType == 'Individual') {
            acc.Name = firstName + ' ' + lastName;
            acc.Type = 'Customer - Direct';
        } else {
            acc.Name = companyName;
            acc.Type = 'Customer - Channel';
        }
        insert acc;

        Contact con = new Contact(
            AccountId = acc.Id,
            FirstName = firstName,
            LastName = lastName,
            Email = email,
            Phone = phone
        );
        insert con;

        Id pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
        Opportunity opp = new Opportunity(
            AccountId = acc.Id,
            Name = opportunityName,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = pbId,
            CurrencyIsoCode = currencyCode
        );
        insert opp;

        insert new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId     = con.Id,
            IsPrimary     = true,
            Role          = 'Decision Maker'
        );

        SBQQ__Quote__c q = new SBQQ__Quote__c(
            SBQQ__Account__c = acc.Id,
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__PricebookId__c = pbId,
            CurrencyIsoCode = currencyCode,
            SBQQ__Primary__c = true,
            SBQQ__StartDate__c = Date.today(),
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__Status__c = 'Draft'
        );
        insert q;

        q = [SELECT Id, Name FROM SBQQ__Quote__c WHERE Id = :q.Id];
        return new Map<String, String>{ 'id' => q.Id, 'name' => q.Name };
    }

    /**
     * @description Creates a quote for an existing customer and opportunity.
     */
    public static Map<String, String> createQuoteForExistingCustomer(String accountId, String opportunityId, String currencyCode) {
        if (String.isBlank(accountId) || String.isBlank(opportunityId)) {
            throw new AuraHandledException('Account and Opportunity are required');
        }
        Opportunity opp = [SELECT Pricebook2Id FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        Id pbId = opp.Pricebook2Id != null ? opp.Pricebook2Id : [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
        
        if (opp.Pricebook2Id == null) {
            opp.Pricebook2Id = pbId;
            update opp;
        }

        // CPQ blocks setting a new primary quote when an ordered quote already exists
        // on the opportunity. Check first to avoid FIELD_CUSTOM_VALIDATION_EXCEPTION.
        Integer orderedCount = [
            SELECT COUNT() FROM SBQQ__Quote__c
            WHERE SBQQ__Opportunity2__c = :opportunityId
              AND SBQQ__Ordered__c = true
        ];
        Boolean isPrimary = (orderedCount == 0);

        SBQQ__Quote__c q = new SBQQ__Quote__c(
            SBQQ__Account__c          = accountId,
            SBQQ__Opportunity2__c     = opportunityId,
            SBQQ__PricebookId__c      = pbId,
            CurrencyIsoCode           = currencyCode,
            SBQQ__Primary__c          = isPrimary,
            SBQQ__StartDate__c        = Date.today(),
            SBQQ__SubscriptionTerm__c = 12,
            SBQQ__Status__c           = 'Draft'
        );
        insert q;

        q = [SELECT Id, Name FROM SBQQ__Quote__c WHERE Id = :q.Id];
        return new Map<String, String>{ 'id' => q.Id, 'name' => q.Name };
    }
}
