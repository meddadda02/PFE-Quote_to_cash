declare module "@salesforce/apex/CPQQuoteController.getQuoteHeader" {
  export default function getQuoteHeader(param: {quoteId: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQQuoteController.updateQuoteStatus" {
  export default function updateQuoteStatus(param: {quoteId: any, status: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQQuoteController.createOpportunityForAccount" {
  export default function createOpportunityForAccount(param: {accountId: any, oppName: any, closeDate: any, currencyCode: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQQuoteController.getNexaLinkTemplateId" {
  export default function getNexaLinkTemplateId(): Promise<any>;
}
declare module "@salesforce/apex/CPQQuoteController.generateDocument" {
  export default function generateDocument(param: {quoteId: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQQuoteController.generateAndSendEmail" {
  export default function generateAndSendEmail(param: {quoteId: any}): Promise<any>;
}
declare module "@salesforce/apex/CPQQuoteController.generateAndSendForSignature" {
  export default function generateAndSendForSignature(param: {quoteId: any}): Promise<any>;
}
