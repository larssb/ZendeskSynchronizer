/*********************************************************\
	- updateZendeskUsers.ts updates Zendesk users -
    It does this from the incoming JSON data. This data is
    incoming AD users from the different source AD's in play.
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
        console.log("- updateZendeskUsers invoked -");
    
        var users: JSON = expressReg.body;
        
        console.log(users);

        // Request the Zendesk REST API to update the customer user
        zendeskClient.users.updateMany(users, function (err, req, result) {
            if (err) {
                console.log(err);
                expressRes.sendStatus(500);
                return;
            }
            
            // Updating the users to Zendesk succeeded. TODO: Response comes back as a job. Get this possibly and do stuff..... 
            console.log(JSON.stringify(result));
            expressRes.sendStatus(200);
        });
    });

module.exports = router;