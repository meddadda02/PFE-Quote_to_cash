List<SBQQ__QuoteLine__c> allLines = [SELECT Id, SBQQ__AdditionalDiscount__c, SBQQ__Discount__c, SBQQ__AdditionalDiscountAmount__c, Discount_Breakdown__c FROM SBQQ__QuoteLine__c];
for (SBQQ__QuoteLine__c l : allLines) {
    // Clear old feedback loop values
    l.SBQQ__AdditionalDiscount__c = null;
    l.SBQQ__Discount__c = null;
    l.SBQQ__AdditionalDiscountAmount__c = null;
    // We can also clear breakdown so user doesn't see old cached text
    if (l.Discount_Breakdown__c != null && l.Discount_Breakdown__c.contains('Price Rule additional')) {
        l.Discount_Breakdown__c = 'Please click Calculate to refresh pricing with the new engine.';
    }
}
update allLines;
System.debug('Cleaned up ' + allLines.size() + ' quote lines.');
