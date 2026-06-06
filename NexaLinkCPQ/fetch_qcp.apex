SBQQ__CustomScript__c s = [SELECT SBQQ__Code__c FROM SBQQ__CustomScript__c WHERE Name = 'TelecomQCP' LIMIT 1];
System.debug('---QCP_CODE_START---');
System.debug(s.SBQQ__Code__c);
System.debug('---QCP_CODE_END---');
