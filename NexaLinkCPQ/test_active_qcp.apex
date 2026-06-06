SBQQ__CustomScript__c s = [SELECT Id, SBQQ__Code__c FROM SBQQ__CustomScript__c WHERE Name = 'TelecomQCP' LIMIT 1];
String oldCode = s.SBQQ__Code__c;
s.SBQQ__Code__c = 'export function onBeforeCalculate(quote, lines, conn) { throw new Error("TESTING_IF_THIS_SCRIPT_RUNS"); }\n' + oldCode;
update s;
System.debug('INJECTED ERROR INTO TelecomQCP');

// Now run a calculation
SBQQ__Quote__c q = [SELECT Id FROM SBQQ__Quote__c WHERE Name = 'Q-00594' LIMIT 1];
CPQPricingController.calculatePricing(q.Id);

System.debug('CALCULATION COMPLETED WITHOUT ERROR!');

// Restore old code immediately
s.SBQQ__Code__c = oldCode;
update s;
System.debug('RESTORED CODE');
