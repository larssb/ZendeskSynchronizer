/*********************************************************\
	- getZendeskOrganization.ts queries Zendesk for 
    an Zendesk organizations.
    It does this by querying Zendesk based on an unique
    identificator. GUID/K on O environements and debitor number
    on ...
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
        console.log("- getZendeskOrganization invoked -");

        var companyExternalID: JSON = expressReg.body;
        
        console.log("Company external ID retrieved: " + companyExternalID.external_id);    

        // Request the Zendesk REST API to get the customer organization
        zendeskClient.organizations.search(companyExternalID, function (err, req, result) {
            if (err) {
                console.log(err);
                expressRes.sendStatus(500);
                return;
            }
            
            // Getting the company Zendesk organization succeeded. Send it to requesting party.
            if (result !== null && result.length > 0) {
                var zendeskOrgID = result[0].id;
                var zendeskOrgName = result[0].name;
                expressRes.status(200).json({ "zendeskOrgId": [zendeskOrgID],
                                            "zendeskOrgName": [zendeskOrgName] });
                return;
            } else {
                expressRes.status(404).json( "No Zendesk org found with specified ID" );
                return;
            }
        });
    });

module.exports = router;