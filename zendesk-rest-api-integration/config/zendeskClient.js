/******************************************************\
    - zendeskClient instantiate a Zendesk client -
/******************************************************/
var zendesk = require('node-zendesk');
var prodZendeskClient = zendesk.createClient({
    username: 'InventioZendeskDev@inventio.it',
    token: 'yTrTOptiUP93kPHEv6b9HOX65xIEpKoNdsDRIzEb',
    remoteUri: 'https://inventio.zendesk.com/api/v2'
});
var sandboxZendeskClient = zendesk.createClient({
    username: 'InventioZendeskDev@inventio.it',
    token: 'cD3YptU9maAwP0vvG8YEt9b8ZOE0ZcSEf4r8JlTh',
    remoteUri: 'https://inventio1472026149.zendesk.com/api/v2'
});
var isSandboxMode = process.env.NODE_ENV && process.env.NODE_ENV.indexOf('sandbox') !== -1 ? true : false;
if (isSandboxMode === true) {
    var zendeskClient = sandboxZendeskClient;
}
else {
    var zendeskClient = prodZendeskClient;
}
module.exports = zendeskClient;
//# sourceMappingURL=zendeskClient.js.map