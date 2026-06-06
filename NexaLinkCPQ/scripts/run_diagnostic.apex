SBQQ__CustomScript__c s = [SELECT Id, SBQQ__Code__c FROM SBQQ__CustomScript__c WHERE Name = 'TelecomQCP' LIMIT 1];
String originalCode = s.SBQQ__Code__c;

try {
    // 1. Set to empty QCP
    s.SBQQ__Code__c = 'export function onBeforeCalculate(quote, lines, conn) { return Promise.resolve(); }\nexport function onAfterCalculate(quote, lines, conn) { return Promise.resolve(); }';
    update s;
    System.debug('--- DIALOG: DISABLED QCP ---');

    // 2. Run calculation
    System.debug('--- DIALOG: RUNNING CALCULATION WITH EMPTY QCP ---');
    String qJson = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', 'a0qQy0000086v8fIAA');
    String cJson = SBQQ.ServiceRouter.load('SBQQ.QuoteAPI.QuoteCalculator', 'a0qQy0000086v8fIAA', qJson);
    System.debug('cJson length: ' + (cJson != null ? String.valueOf(cJson.length()) : 'null'));
    System.debug('--- DIALOG: SUCCESS WITH EMPTY QCP! ---');

} catch (Exception e) {
    System.debug('--- DIALOG: FAILED WITH EMPTY QCP: ' + e.getMessage() + '\n' + e.getStackTraceString());
} finally {
    // 3. Restore QCP
    s.SBQQ__Code__c = originalCode;
    update s;
    System.debug('--- DIALOG: RESTORED ORIGINAL QCP ---');
}
