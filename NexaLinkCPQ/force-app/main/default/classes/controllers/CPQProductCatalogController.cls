/**
 * @description Controller for CPQ Product Catalog.
 * Reorganized by a Junior Developer.
 */
public without sharing class CPQProductCatalogController {
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getProducts(String searchTerm, String currencyCode) {
        return CPQProductCatalogModel.getProducts(searchTerm, currencyCode);
     }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getBundles(String searchTerm, String currencyCode) {
        return CPQProductCatalogModel.getBundles(searchTerm, currencyCode);
    }

    @AuraEnabled
    public static Map<String, Object> getBundleWithFeatures(String bundleCode, String currencyCode) {
        return CPQProductCatalogModel.getBundleWithFeatures(bundleCode, currencyCode);
    }
}
