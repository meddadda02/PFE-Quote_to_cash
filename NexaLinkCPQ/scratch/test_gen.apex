HttpRequest req = new HttpRequest();
req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/apexrest/SBQQ/ServiceRouter');
req.setMethod('POST');
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
req.setHeader('Content-Type', 'application/json');
req.setTimeout(30000);

String model = JSON.serialize(new Map<String, Object>{
    'quoteId'    => 'a0qQy000008IhwLIAS',
    'templateId' => 'a0oQy000000LwKLIA0'
});
req.setBody(JSON.serialize(new Map<String, Object>{
    'saver' => 'SBQQ.QuoteDocumentSaver',
    'model' => model
}));

HttpResponse res = new Http().send(req);
System.debug('HTTP STATUS: ' + res.getStatusCode());
System.debug('HTTP BODY: ' + res.getBody());
