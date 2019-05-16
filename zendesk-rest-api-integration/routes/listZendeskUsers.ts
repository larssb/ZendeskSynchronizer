/*********************************************************\
    - listZendeskUsers.ts lists Zendesk users -
    Based on a companies org. id on Zendesk. This needs
    to be looked up via the /getZendeskOrganization route
/*********************************************************/

// First references to TypeScript declaration files used by the src code
/// <reference path="../TypeScriptDeclarationFiles/body-parser.d.ts"/>;
/// <reference path="../TypeScriptDeclarationFiles/express.d.ts"/>;

/* LOAD MODULES */
import bodyParser = require('body-parser');
import express = require('express');
var zendeskClient = require('../zendesk/zendeskClient');

/* MODULES CONFIGURATION */
// -- body-parser
var parsePayload = bodyParser.json( {limit: '50mb'} );
// -- EXPRESS JS
var router = express.Router();

/* ROUTE CODE FROM HERE */
router.route('/')
    .post(parsePayload, function (expressReg, expressRes) {
        console.log(" ----- ");
        console.log("- listZendeskUsers invoked -");
    
        var companyZendeskOrgID: JSON = expressReg.body;
        
        console.log("CompanyZendeskOrgID retrieved: " + companyZendeskOrgID);

        // Request the Zendesk REST API to update the customer user
        zendeskClient.users.listByOrganization(companyZendeskOrgID, function (err, req, result) {
            if (err) {
                console.log(err);
                expressRes.sendStatus(500);
                return;
            }
            
            // Retrieving a list of users underneath an Organization on Zendesk succeeded.
            var userList = result;
            expressRes.status(200).json( userList );
        });
    });

module.exports = router;