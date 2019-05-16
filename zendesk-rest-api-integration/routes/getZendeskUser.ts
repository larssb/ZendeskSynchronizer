/*********************************************************\
	- getZendeskUser.ts queries Zendesk for 
    an organizations, Zendesk organization ID.
    It does this by querying Zendesk based on a specific
    internal number assigned the customer.
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
        console.log("- getZendeskUser invoked -");

        var userUniqueIdentifier: JSON = expressReg.body;
        console.log("id received: " + userUniqueIdentifier.external_id);

        // Request the Zendesk REST API to get the customer user
        zendeskClient.users.search(userUniqueIdentifier, function (err, req, result) {
            if (err) {
                console.log(err);
                expressRes.sendStatus(500);
                return;
            }
            
            // Getting the Zendesk user succeeded. Send it to requesting party.
            if (result !== null && result.length > 0) {
                expressRes.status(200).json(result);
                return;
            } else {
                expressRes.status(404).json( "No Zendesk user found with specified ID" );
                return;
            }
        });
    });

module.exports = router;