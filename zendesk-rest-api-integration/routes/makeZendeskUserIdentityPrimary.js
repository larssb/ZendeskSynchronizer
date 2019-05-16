/*********************************************************\
    - makeZendeskUserIdentityPrimary.ts makes an identity
    on a Zendesk user the primary identity of the user -
/*********************************************************/
/// <reference path="../TypeScriptDeclarationFiles/body-parser.d.ts"/>;
/// <reference path="../TypeScriptDeclarationFiles/express.d.ts"/>;
var bodyParser = require('body-parser');
var express = require('express');
var zendeskClient = require('../zendesk/zendeskClient');
var parsePayload = bodyParser.json();
var router = express.Router();
router.route('/')
    .put(parsePayload, function (expressReg, expressRes) {
    console.log(" ----- ");
    console.log("- makeZendeskUserIdentityPrimary invoked -");
    var userID = expressReg.body.usersIdOnZendesk;
    var identityID = expressReg.body.usersIdentityIdOnZendesk;
    zendeskClient.useridentities.makePrimary(userID, identityID, function (err, req, result) {
        if (err) {
            console.log(err);
            expressRes.sendStatus(err.statusCode);
            return;
        }
        expressRes.status(200).json(result);
    });
});
module.exports = router;
//# sourceMappingURL=makeZendeskUserIdentityPrimary.js.map