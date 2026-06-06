/**
 * @description Controller for the main CPQ configurator dashboard.
 * Reorganized by a Junior Developer.
 */
public without sharing class CPQDashboardController {
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getQuotes(String searchTerm) {
        return CPQDashboardModel.getQuotes(searchTerm);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRecentQuotes() {
        return CPQDashboardModel.getRecentQuotes();
    }
}
