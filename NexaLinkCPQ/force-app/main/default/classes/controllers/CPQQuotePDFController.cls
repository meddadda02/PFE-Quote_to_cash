public without sharing class CPQQuotePDFController {

    public SBQQ__Quote__c quote { get; private set; }
    public List<SBQQ__QuoteLine__c> lines { get; private set; }
    public Decimal totalNet { get; private set; }
    public String currencyName { get; private set; }
    public String subscriptionTermStr { get; private set; }
    public Boolean isDraft { get; private set; }
    public Boolean hasExpirationDate { get; private set; }
    public Boolean hasStartDate { get; private set; }
    public Boolean hasEndDate { get; private set; }
    public Boolean hasBillingFrequency { get; private set; }
    public Boolean includeCoverPage { get; private set; }
    public String billingName { get; private set; }
    public String salesRepName { get; private set; }

    public CPQQuotePDFController() {
        String quoteId = ApexPages.currentPage().getParameters().get('id');
        if (String.isBlank(quoteId)) return;

        quote = [
            SELECT Id, Name, SBQQ__Status__c,
                   SBQQ__Account__r.Name,
                   SBQQ__Opportunity2__r.Name,
                   CurrencyIsoCode, CreatedDate,
                   SBQQ__ExpirationDate__c,
                   SBQQ__StartDate__c,
                   SBQQ__EndDate__c,
                   SBQQ__BillingFrequency__c,
                   SBQQ__SubscriptionTerm__c,
                   Include_Cover_Page__c,
                   SBQQ__BillingName__c,
                   SBQQ__SalesRep__r.Name,
                   Owner.Name
            FROM SBQQ__Quote__c
            WHERE Id = :quoteId
            LIMIT 1
        ];

        lines = [
            SELECT SBQQ__ProductName__c, SBQQ__Quantity__c,
                   SBQQ__ListPrice__c, SBQQ__Discount__c, SBQQ__NetPrice__c,
                   Discount_Breakdown__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :quoteId
            ORDER BY CreatedDate ASC
        ];

        totalNet = 0;
        for (SBQQ__QuoteLine__c l : lines) {
            if (l.SBQQ__NetPrice__c != null) totalNet += l.SBQQ__NetPrice__c;
        }

        currencyName = quote.CurrencyIsoCode == 'MAD' ? 'Moroccan Dirham'
                     : quote.CurrencyIsoCode == 'EUR' ? 'Euro'
                     : quote.CurrencyIsoCode == 'USD' ? 'US Dollar'
                     : quote.CurrencyIsoCode;

        subscriptionTermStr = quote.SBQQ__SubscriptionTerm__c != null
            ? String.valueOf(Integer.valueOf(quote.SBQQ__SubscriptionTerm__c)) + ' months'
            : '—';

        isDraft             = quote.SBQQ__Status__c == 'Draft';
        hasExpirationDate   = quote.SBQQ__ExpirationDate__c   != null;
        hasStartDate        = quote.SBQQ__StartDate__c         != null;
        hasEndDate          = quote.SBQQ__EndDate__c           != null;
        hasBillingFrequency = String.isNotBlank(quote.SBQQ__BillingFrequency__c);

        includeCoverPage    = quote.Include_Cover_Page__c == true 
                           || ApexPages.currentPage().getParameters().get('includeCoverPage') == 'true';
        billingName         = String.isNotBlank(quote.SBQQ__BillingName__c) ? quote.SBQQ__BillingName__c : quote.SBQQ__Account__r.Name;
        salesRepName        = quote.SBQQ__SalesRep__c != null ? quote.SBQQ__SalesRep__r.Name : quote.Owner.Name;
    }
}
