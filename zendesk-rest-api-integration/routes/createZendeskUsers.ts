/*************************************************************\
	- createZendeskUsers creates Zendesk users -
    Based on users located in AD organizational units
    which are considered to be company entities.
/*************************************************************/

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

/* THIS MODULES CODE FROM HERE */
router.route('/')
    .post(parsePayload, function (expressReg, expressRes) {
        console.log(" ----- ");
        console.log("- createZendeskUsers invoked -");

        var users: JSON = expressReg.body;
        
        // Show the users to be created on Zendesk in the console
        console.log(users);

        // Request the Zendesk REST API to create the users coming in
        zendeskClient.users.createMany(users, function (err, req, result) {
            if (err) {
                console.log(err);
                expressRes.sendStatus(500);
                return;
            }
            
            console.log(JSON.stringify(result)); // CONTAINS JOB STATUS WHICH WE COULD USE AT SOME POINT!!!!
            expressRes.sendStatus(201); // Creation of the Zendesk users succeeded -- send HTTP201.
        });
    });

module.exports = router;