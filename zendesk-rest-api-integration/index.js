/*******************************************************
   - index.ts initiates and defines ExpresJS routes  -
********************************************************/
/// <reference path="./TypeScriptDeclarationFiles/express.d.ts"/>;
/// <reference path="./TypeScriptDeclarationFiles/node.d.ts"/>;
var express = require('express');
var server = express();
var createZendeskOrg = require('./routes/createZendeskOrg');
server.use('/createZendeskOrg', createZendeskOrg);
var updateZendeskOrg = require('./routes/updateZendeskOrg');
server.use('/updateZendeskOrg', updateZendeskOrg);
var getZendeskOrganization = require('./routes/getZendeskOrganization');
server.use('/getZendeskOrganization', getZendeskOrganization);
var createZendeskUsers = require('./routes/createZendeskUsers');
server.use('/createZendeskUsers', createZendeskUsers);
var updateZendeskUsers = require('./routes/updateZendeskUsers');
server.use('/updateZendeskUsers', updateZendeskUsers);
var getZendeskUser = require('./routes/getZendeskUser');
server.use('/getZendeskUser', getZendeskUser);
var listZendeskUsers = require('./routes/listZendeskUsers');
server.use('/listZendeskUsers', listZendeskUsers);
var createZendeskUserIdentity = require('./routes/createZendeskUserIdentity');
server.use('/createZendeskUserIdentity', createZendeskUserIdentity);
var makeZendeskUserIdentityPrimary = require('./routes/makeZendeskUserIdentityPrimary');
server.use('/makeZendeskUserIdentityPrimary', makeZendeskUserIdentityPrimary);
server.disable('x-powered-by');
server.listen(8080);
console.log('Inventio.IT - NodeJS SRV for Zendesk integration started successfully');
//# sourceMappingURL=index.js.map