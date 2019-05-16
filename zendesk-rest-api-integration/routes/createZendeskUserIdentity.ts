/*********************************************************\
    - createZendeskUserIdentity.ts adds an identity to a 
    Zendesk user -
    Based on an AD user.
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
        console.log("- createZendeskUserIdentity invoked -");
    
        var userId: JSON = expressReg.body.usersIdOnZendesk;
        var userIdentityData: JSON = expressReg.body.identityDataToZendesk;

        // Request the Zendesk REST API to create an identity on the Zendesk user
        zendeskClient.useridentities.create(userId, userIdentityData, function (err, req, result) {
            if (err) {
                console.log(err);
                expressRes.sendStatus(err.statusCode);
                return;
            }
            
            // Creation of the identity on the Zendesk user succeeded.
            expressRes.status(201).json(result);
        });
    });

module.exports = router;