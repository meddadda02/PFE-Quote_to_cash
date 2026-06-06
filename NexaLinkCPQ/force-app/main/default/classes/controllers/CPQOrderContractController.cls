/**
 * @description Controller for Order & Contract actions.
 * Reorganized by a Junior Developer.
 */
public without sharing class CPQOrderContractController {
    
    @AuraEnabled
    public static Map<String, Object> markQuoteOrdered(String quoteId) {
        try {
            return CPQOrderContractModel.markQuoteOrdered(quoteId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> markOrderContracted(String orderId) {
        try {
            return CPQOrderContractModel.markOrderContracted(orderId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getOrdersForQuote(String quoteId) {
        return CPQOrderContractModel.getOrdersForQuote(quoteId);
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getOrderHeader(String orderId) {
        return CPQOrderContractModel.getOrderHeader(orderId);
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getOrderLines(String orderId) {
        return CPQOrderContractModel.getOrderLines(orderId);
    }

    @AuraEnabled
    public static Map<String, Object> updateOrderStatus(String orderId, String status) {
        try {
            return CPQOrderContractModel.updateOrderStatus(orderId, status);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getContractsForOrder(String orderId) {
        return CPQOrderContractModel.getContractsForOrder(orderId);
    }
}
