/*********************************************************\
    - createZendeskUserIdentity.ts adds an identity to a Zendesk
    user -
    It does this from the incoming data. Which is Inventio
    customer user data.
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
    console.log("- createZendeskUserIdentity invoked -");
    var userId = expressReg.body.usersIdOnZendesk;
    var userIdentityData = expressReg.body.identityDataToZendesk;
    zendeskClient.useridentities.create(userId, userIdentityData, function (err, req, result) {
        if (err) {
            console.log(err);
            expressRes.sendStatus(err.statusCode);
            return;
        }
        expressRes.status(201).json(result);
    });
});
module.exports = router;
//# sourceMappingURL=createZendeskUserIdentity.js.map