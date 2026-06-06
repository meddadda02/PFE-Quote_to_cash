/**
 * @description Deprecated controller class.
 * Retained solely to prevent compilation/deployment issues with the active Flow
 * "APPROVED_DISCOUNT" which references the invocable pricing calculation method.
 */
public without sharing class CPQConfiguratorController {
    
    /**
     * @description Delegator method for Flow compatibility.
     * Routes requests to the new CPQPricingModel.
     */
    @InvocableMethod(label='Calculate CPQ Pricing')
    public static void calculatePricingInvocable(List<Id> quoteIds) {
        CPQPricingModel.calculatePricingInvocable(quoteIds);
    }
}
