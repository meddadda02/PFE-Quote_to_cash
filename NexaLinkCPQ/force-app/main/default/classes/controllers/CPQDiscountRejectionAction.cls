public without sharing class CPQDiscountRejectionAction {

    @InvocableMethod(label='Handle Discount Rejection')
    public static void handleDiscountRejectionInvocable(List<Id> quoteIds) {
        for (Id quoteId : quoteIds) {
            CPQPricingModel.handleDiscountRejection(quoteId);
        }
    }
}
