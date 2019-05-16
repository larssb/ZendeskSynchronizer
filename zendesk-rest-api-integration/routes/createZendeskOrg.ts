/*********************************************************\
	- createZendeskOrgs.ts creates Zendesk organizations -
    Based on AD organizational units.
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
    .post(parsePayload, function (expressReg, expressRes) {
        console.log(" ----- ");
        console.log("- createZendeskOrg invoked -");
    
        var organization: JSON = expressReg.body;

        // Request the Zendesk REST API to create the customer organization
        zendeskClient.organizations.create(organization, function (err, req, result) {
            if (err) {
                console.log(err);
                expressRes.sendStatus(500);
                return;
            }
            
            // Creation of the Zendesk organization succeeded. Send Organization ID defined by Zendesk & ok.
            var zendeskOrgID = result.id;
            expressRes.status(201).json({ "zendeskOrgId": [ zendeskOrgID ] });
        });
    });

module.exports = router;