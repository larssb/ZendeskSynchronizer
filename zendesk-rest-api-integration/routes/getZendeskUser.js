/*********************************************************\
    - getZendeskUser.ts queries Zendesk for
    an Inventio.IT customers organizations ID.
    It does this by querying Zendesk based on the debitor
    number on the customer, assigned by Inventio.IT.
/*********************************************************/
/// <reference path="../TypeScriptDeclarationFiles/body-parser.d.ts"/>;
/// <reference path="../TypeScriptDeclarationFiles/express.d.ts"/>;
var bodyParser = require('body-parser');
var express = require('express');
var zendeskClient = require('../zendesk/zendeskClient');
var parsePayload = bodyParser.json();
var router = express.Router();
router.route('/')
    .post(parsePayload, function (expressReg, expressRes) {
    console.log(" ----- ");
    console.log("- getZendeskUser invoked -");
    var userUniqueIdentifier = expressReg.body;
    console.log("id received: " + userUniqueIdentifier.external_id);
    zendeskClient.users.search(userUniqueIdentifier, function (err, req, result) {
        if (err) {
            console.log(err);
            expressRes.sendStatus(500);
            return;
        }
        if (result !== null && result.length > 0) {
            expressRes.status(200).json(result);
            return;
        }
        else {
            expressRes.status(404).json("No Zendesk user found with specified ID");
            return;
        }
    });
});
module.exports = router;
//# sourceMappingURL=getZendeskUser.js.map