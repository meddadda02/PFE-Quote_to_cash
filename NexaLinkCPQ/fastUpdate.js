const fs = require('fs');
const code = fs.readFileSync('qcp_fixed.js', 'utf8');
const id = 'a0BQy00000ygtAPMAY'; // Using the ID previously obtained successfully
const escapedCode = code
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\r/g, '')
    .replace(/\n/g, '\\n');
const apex = `SBQQ__CustomScript__c s = new SBQQ__CustomScript__c(Id = '${id}'); s.SBQQ__Code__c = '${escapedCode}'; update s;`;
fs.writeFileSync('update_qcp.apex', apex);
console.log('Fast update script generated update_qcp.apex without SF API calls!');
