SBQQ__CustomScript__c s = [SELECT Id, SBQQ__Code__c FROM SBQQ__CustomScript__c WHERE Name = 'TelecomQCP' LIMIT 1];
s.SBQQ__Code__c = s.SBQQ__Code__c + '\n// FORCE CACHE INVALIDATION ' + System.currentTimeMillis();
update s;
System.debug('Forced cache invalidation on TelecomQCP');
