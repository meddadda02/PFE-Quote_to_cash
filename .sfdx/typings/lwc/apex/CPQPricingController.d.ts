declare module "@salesforce/apex/CPQPricingController.syncProductsToQuote" {
  export default function syncProductsToQuote(param: {quoteId: any, productsJson: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQPricingController.clearAndAddAllBundles" {
  export default function clearAndAddAllBundles(param: {quoteId: any, bundlesJson: any, standaloneJson: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQPricingController.calculatePricing" {
  export default function calculatePricing(param: {quoteId: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQPricingController.getQuoteLines" {
  export default function getQuoteLines(param: {quoteId: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQPricingController.submitHighDiscountForApproval" {
  export default function submitHighDiscountForApproval(param: {quoteId: any, comments: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQPricingController.handleDiscountRejection" {
  export default function handleDiscountRejection(param: {quoteId: any}): Promise<any>;
}
