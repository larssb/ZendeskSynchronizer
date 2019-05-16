/*********************************************************\
  - updateZendeskOrgs.ts updates a Zendesk organization -
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
var parsePayload = bodyParser.json();
// -- EXPRESS JS
var router = express.Router();

/* ROUTE CODE FROM HERE */
router.route('/')
    .put(parsePayload, function (expressReg, expressRes) {
        console.log(" ----- ");
        console.log("- updateZendeskOrg invoked -");
    
        var organization: JSON = expressReg.body.orgToZendesk;
        var organizationID: JSON = expressReg.body.organizationID;

        // Request the Zendesk REST API to update the customer organization
        zendeskClient.organizations.update(organizationID, organization, function (err, req, result) {
            if (err) {
                console.log(err);
                expressRes.sendStatus(500);
                return;
            }
            
            // Updating the Zendesk organization succeeded.
            var zendeskOrgID = result.id;
            expressRes.status(200).json({ "zendeskOrgId": [ zendeskOrgID ] });
        });
    });

module.exports = router;