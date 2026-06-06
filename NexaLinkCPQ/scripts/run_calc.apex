try {
    System.debug('--- ATTEMPT TO MARK ORDERED ---');
    Map<String, Object> result = CPQOrderContractModel.markQuoteOrdered('a0qQy0000086v8fIAA');
    System.debug('Order Result: ' + JSON.serializePretty(result));
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage() + '\nStack: ' + e.getStackTraceString());
}
