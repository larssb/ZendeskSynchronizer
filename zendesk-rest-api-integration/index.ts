/*******************************************************
   - index.ts initiates and defines ExpresJS routes  -
********************************************************/

// First references to TypeScript declaration files used by the src code
/// <reference path="./TypeScriptDeclarationFiles/express.d.ts"/>;
/// <reference path="./TypeScriptDeclarationFiles/node.d.ts"/>;

// Import modules for TypeScript to be able to 'see' them
import express = require('express');
var server = express();

/*
 * Routes from here
 */
    // -- ORGS --
// create Zendesk organization route
var createZendeskOrg: express.Router = require('./routes/createZendeskOrg');
server.use('/createZendeskOrg', createZendeskOrg);

// update Zendesk organization route
var updateZendeskOrg: express.Router = require('./routes/updateZendeskOrg');
server.use('/updateZendeskOrg', updateZendeskOrg);

// Get company/customer Zendesk org. route
var getZendeskOrganization: express.Router = require('./routes/getZendeskOrganization');
server.use('/getZendeskOrganization', getZendeskOrganization);

    // -- USERS --
// create Zendesk users route
var createZendeskUsers: express.Router = require('./routes/createZendeskUsers');
server.use('/createZendeskUsers', createZendeskUsers);

// update Zendesk users route
var updateZendeskUsers: express.Router = require('./routes/updateZendeskUsers');
server.use('/updateZendeskUsers', updateZendeskUsers);

// Get Zendesk user route
var getZendeskUser: express.Router = require('./routes/getZendeskUser');
server.use('/getZendeskUser', getZendeskUser);

// Get list of users underneath Zendesk org. route
var listZendeskUsers: express.Router = require('./routes/listZendeskUsers');
server.use('/listZendeskUsers', listZendeskUsers);

// Route for creating an identity on a Zendesk user 
var createZendeskUserIdentity: express.Router = require('./routes/createZendeskUserIdentity');
server.use('/createZendeskUserIdentity', createZendeskUserIdentity);

// Route for making an identity the primary one on a Zendesk user 
var makeZendeskUserIdentityPrimary: express.Router = require('./routes/makeZendeskUserIdentityPrimary');
server.use('/makeZendeskUserIdentityPrimary', makeZendeskUserIdentityPrimary);

/*
 * General ExpressJS server initiation & config
 */
// Do not advertise use of ExpressJS
server.disable('x-powered-by');

// Initiate the ExpressJS server
server.listen(8080);
console.log('The Zendesk Synchronizer NodeJS server started successfully');