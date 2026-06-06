const { execSync } = require('child_process');
const fs = require('fs');

const code = fs.readFileSync('qcp_fixed.js', 'utf8');

try {
    // Query the record ID of the Custom Script
    const query = execSync(`sf data query -q "SELECT Id FROM SBQQ__CustomScript__c WHERE Name = 'TelecomQCP' LIMIT 1" --json`);
    const id = JSON.parse(query.toString()).result.records[0].Id;

    // Properly escape backslashes, single quotes, and newlines for Apex single-quoted string literals
    const escapedCode = code
        .replace(/\\/g, '\\\\')
        .replace(/'/g, "\\'")
        .replace(/\r/g, '')
        .replace(/\n/g, '\\n');

    const apex = `SBQQ__CustomScript__c s = new SBQQ__CustomScript__c(Id = '${id}'); s.SBQQ__Code__c = '${escapedCode}'; update s;`;
    fs.writeFileSync('update_qcp.apex', apex);

    console.log('Apex script created: update_qcp.apex');
} catch (e) {
    console.error('Error generating update_qcp.apex: ', e);
}
