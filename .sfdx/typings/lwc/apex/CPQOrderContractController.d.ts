declare module "@salesforce/apex/CPQOrderContractController.markQuoteOrdered" {
  export default function markQuoteOrdered(param: {quoteId: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQOrderContractController.markOrderContracted" {
  export default function markOrderContracted(param: {orderId: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQOrderContractController.getOrdersForQuote" {
  export default function getOrdersForQuote(param: {quoteId: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQOrderContractController.getOrderHeader" {
  export default function getOrderHeader(param: {orderId: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQOrderContractController.getOrderLines" {
  export default function getOrderLines(param: {orderId: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQOrderContractController.updateOrderStatus" {
  export default function updateOrderStatus(param: {orderId: any, status: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQOrderContractController.getContractsForOrder" {
  export default function getContractsForOrder(param: {orderId: any}): Promise<any>;
}
