/*********************************************************\
	- makeZendeskUserIdentityPrimary.ts makes an identity 
    on a Zendesk user the primary identity of the user -
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
        console.log("- makeZendeskUserIdentityPrimary invoked -");
    
        var userID: JSON = expressReg.body.usersIdOnZendesk;
        var identityID: JSON = expressReg.body.usersIdentityIdOnZendesk;

        // Request the Zendesk REST API to make an identity the primary one on the Zendesk user
        zendeskClient.useridentities.makePrimary(userID, identityID, function (err, req, result) {
            if (err) {
                console.log(err);
                expressRes.sendStatus(err.statusCode);
                return;
            }
            
            // Creation of the identity on the Zendesk user succeeded.
            expressRes.status(200).json(result);
        });
    });

module.exports = router;