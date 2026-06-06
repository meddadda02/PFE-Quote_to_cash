/**
 * @description Domain model for simple products, bundles, features, and option hierarchy data.
 * Reorganized by a Junior Developer.
 */
public without sharing class CPQProductCatalogModel {
    
    /**
     * @description Fetches standalone simple products matching the term.
     */
    public static List<Map<String, Object>> getProducts(String searchTerm, String currencyCode) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        String queryTerm = '%' + (searchTerm == null ? '' : searchTerm) + '%';
        String cur = String.isBlank(currencyCode) ? 'MAD' : currencyCode;
        for (PricebookEntry pbe : [SELECT Product2Id, Product2.Name, Product2.Name_FR__c, Product2.ProductCode, 
                                          Product2.Family, Product2.SBQQ__ChargeType__c, UnitPrice
                                    FROM PricebookEntry
                                    WHERE IsActive = true
                                    AND CurrencyIsoCode = :cur
                                    AND (Product2.Name LIKE :queryTerm OR Product2.ProductCode LIKE :queryTerm)
                                    AND Product2.SBQQ__ConfigurationType__c = null
                                    LIMIT 50]) {
            result.add(new Map<String, Object>{
                'id' => pbe.Product2Id, 
                'productId' => pbe.Product2Id, 
                'name' => pbe.Product2.Name, 
                'nameEn' => pbe.Product2.Name, 
                'nameFr' => pbe.Product2.Name_FR__c, 
                'productCode' => pbe.Product2.ProductCode,
                'family' => pbe.Product2.Family, 
                'type' => pbe.Product2.SBQQ__ChargeType__c, 
                'price' => pbe.UnitPrice, 
                'unitPrice' => pbe.UnitPrice
            });
        }
        return result;
    }

    /**
     * @description Fetches product bundles configured in the system.
     */
    public static List<Map<String, Object>> getBundles(String searchTerm, String currencyCode) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        String queryTerm = '%' + (searchTerm == null ? '' : searchTerm) + '%';
        String cur = String.isBlank(currencyCode) ? 'MAD' : currencyCode;
        Set<Id> bundleParentIds = new Set<Id>();
        for (SBQQ__ProductOption__c po : [SELECT SBQQ__ConfiguredSKU__c FROM SBQQ__ProductOption__c WHERE SBQQ__ConfiguredSKU__c != null]) {
            bundleParentIds.add(po.SBQQ__ConfiguredSKU__c);
        }
        for (PricebookEntry pbe : [SELECT Product2Id, Product2.Name, Product2.Name_FR__c, Product2.ProductCode, Product2.Description, UnitPrice
                                   FROM PricebookEntry
                                   WHERE IsActive = true
                                   AND CurrencyIsoCode = :cur
                                   AND (Product2.Name LIKE :queryTerm OR Product2.ProductCode LIKE :queryTerm)
                                   AND (Product2.SBQQ__ConfigurationType__c != null OR Product2Id IN :bundleParentIds)
                                   LIMIT 50]) {
            result.add(new Map<String, Object>{
                'id' => pbe.Product2Id, 
                'productId' => pbe.Product2Id, 
                'name' => pbe.Product2.Name, 
                'nameEn' => pbe.Product2.Name, 
                'nameFr' => pbe.Product2.Name_FR__c, 
                'productCode' => pbe.Product2.ProductCode,
                'description' => pbe.Product2.Description, 
                'descriptionEn' => pbe.Product2.Description, 
                'descriptionFr' => null, 
                'price' => pbe.UnitPrice
            });
        }
        return result;
    }

    /**
     * @description Loads a bundle and all of its associated Features and customizable Options.
     */
    public static Map<String, Object> getBundleWithFeatures(String bundleCode, String currencyCode) {
        Map<String, Object> result = new Map<String, Object>();
        if (String.isBlank(bundleCode)) return result;
        String cur = String.isBlank(currencyCode) ? 'MAD' : currencyCode;
        List<Product2> bundles = [SELECT Id, Name, Name_FR__c, ProductCode 
                                  FROM Product2 
                                  WHERE (ProductCode = :bundleCode OR Id = :bundleCode) AND IsActive = true LIMIT 1];
        if (bundles.isEmpty()) return result;
        Product2 bundle = bundles[0];
        result.put('bundleId', bundle.Id); 
        result.put('bundleName', bundle.Name); 
        result.put('bundleCode', bundle.ProductCode); 
        result.put('nameEn', bundle.Name); 
        result.put('nameFr', bundle.Name_FR__c);
        
        List<SBQQ__ProductFeature__c> feats = [SELECT Id, Name, SBQQ__MinOptionCount__c, SBQQ__MaxOptionCount__c 
                                               FROM SBQQ__ProductFeature__c 
                                               WHERE SBQQ__ConfiguredSKU__c = :bundle.Id 
                                               ORDER BY SBQQ__Number__c];
                                               
         List<SBQQ__ProductOption__c> pos = [SELECT Id, SBQQ__OptionalSKU__c, SBQQ__OptionalSKU__r.Name, 
                                                    SBQQ__OptionalSKU__r.Name_FR__c, SBQQ__OptionalSKU__r.ProductCode, 
                                                    SBQQ__OptionalSKU__r.Family, SBQQ__Bundled__c, SBQQ__Required__c, 
                                                    SBQQ__Selected__c, SBQQ__Quantity__c, SBQQ__Feature__c 
                                             FROM SBQQ__ProductOption__c 
                                             WHERE SBQQ__ConfiguredSKU__c = :bundle.Id 
                                             AND SBQQ__OptionalSKU__r.IsActive = true];
                                            
        Set<Id> opIds = new Set<Id>();
        for (SBQQ__ProductOption__c po : pos) {
            opIds.add(po.SBQQ__OptionalSKU__c);
        }
        Map<Id, Decimal> opPriceMap = new Map<Id, Decimal>();
        for (PricebookEntry pbe : [SELECT Product2Id, UnitPrice 
                                   FROM PricebookEntry 
                                   WHERE Product2Id IN :opIds AND CurrencyIsoCode = :cur AND IsActive = true]) {
            opPriceMap.put(pbe.Product2Id, pbe.UnitPrice);
        }
        
        List<Map<String, Object>> features = new List<Map<String, Object>>();
        for (SBQQ__ProductFeature__c f : feats) {
            List<Map<String, Object>> opts = new List<Map<String, Object>>();
            for (SBQQ__ProductOption__c po : pos) {
                if (po.SBQQ__Feature__c == f.Id) {
                    opts.add(new Map<String, Object>{
                        'optionId' => po.Id, 
                        'productId' => po.SBQQ__OptionalSKU__c, 
                        'productCode' => po.SBQQ__OptionalSKU__r.ProductCode, 
                        'name' => po.SBQQ__OptionalSKU__r.Name, 
                        'nameEn' => po.SBQQ__OptionalSKU__r.Name, 
                        'nameFr' => po.SBQQ__OptionalSKU__r.Name_FR__c, 
                        'price' => opPriceMap.containsKey(po.SBQQ__OptionalSKU__c) ? opPriceMap.get(po.SBQQ__OptionalSKU__c) : 0, 
                        'isBundled' => po.SBQQ__Bundled__c, 
                        'isRequired' => po.SBQQ__Required__c, 
                        'isSelected' => po.SBQQ__Selected__c, 
                        'quantity' => po.SBQQ__Quantity__c != null ? po.SBQQ__Quantity__c : 1
                    });
                }
            }
            features.add(new Map<String, Object>{
                'id' => f.Id, 
                'name' => f.Name, 
                'minOpt' => f.SBQQ__MinOptionCount__c, 
                'maxOpt' => f.SBQQ__MaxOptionCount__c, 
                'options' => opts
            });
        }
        result.put('features', features);
        return result;
    }
}
