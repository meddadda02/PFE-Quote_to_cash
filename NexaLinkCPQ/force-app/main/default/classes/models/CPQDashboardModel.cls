/**
 * @description Domain model for dashboard searches and lists.
 * Reorganized by a Junior Developer.
 */
public without sharing class CPQDashboardModel {
    
    /**
     * @description Returns a list of quotes matching the search query.
     */
    public static List<Map<String, Object>> getQuotes(String searchTerm) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        String queryTerm = '%' + (searchTerm == null ? '' : searchTerm) + '%';
        for (SBQQ__Quote__c quote : [SELECT Id, Name, SBQQ__Account__r.Name, SBQQ__Status__c, SBQQ__NetAmount__c,
                                            CreatedDate, CurrencyIsoCode 
                                     FROM SBQQ__Quote__c 
                                     WHERE Name LIKE :queryTerm OR SBQQ__Account__r.Name LIKE :queryTerm 
                                     ORDER BY CreatedDate DESC LIMIT 20]) {
            result.add(new Map<String, Object>{
                'id' => quote.Id, 
                'name' => quote.Name, 
                'accountName' => quote.SBQQ__Account__r.Name,
                'status' => quote.SBQQ__Status__c, 
                'amount' => quote.SBQQ__NetAmount__c, 
                'createdDate' => quote.CreatedDate,
                'currency' => quote.CurrencyIsoCode
            });
        }
        return result;
    }

    /**
     * @description Returns the 5 most recent quotes.
     */
    public static List<Map<String, Object>> getRecentQuotes() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (SBQQ__Quote__c quote : [SELECT Id, Name, SBQQ__Account__r.Name, SBQQ__Status__c,
                                            SBQQ__NetAmount__c, CreatedDate, CurrencyIsoCode 
                                     FROM SBQQ__Quote__c 
                                     ORDER BY CreatedDate DESC LIMIT 5]) {
            result.add(new Map<String, Object>{
                'id' => quote.Id, 
                'name' => quote.Name, 
                'accountName' => quote.SBQQ__Account__r.Name, 
                'status' => quote.SBQQ__Status__c, 
                'amount' => quote.SBQQ__NetAmount__c, 
                'createdDate' => quote.CreatedDate, 
                'currency' => quote.CurrencyIsoCode
            });
        }
        return result;
    }
}
