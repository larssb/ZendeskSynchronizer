/*************************************************************\
    - createZendeskUsers creates Zendesk users -
    It does this from the incoming data. Which is the users
    of Inventio's customers. These users are located in AD
    organizational units in Inventio's active directories.
/*************************************************************/
/// <reference path="../TypeScriptDeclarationFiles/body-parser.d.ts"/>;
/// <reference path="../TypeScriptDeclarationFiles/express.d.ts"/>;
var bodyParser = require('body-parser');
var express = require('express');
var zendeskClient = require('../zendesk/zendeskClient');
var parsePayload = bodyParser.json({ limit: '50mb' });
var router = express.Router();
router.route('/')
    .post(parsePayload, function (expressReg, expressRes) {
    console.log(" ----- ");
    console.log("- createZendeskUsers invoked -");
    var users = expressReg.body;
    console.log(users);
    zendeskClient.users.createMany(users, function (err, req, result) {
        if (err) {
            console.log(err);
            expressRes.sendStatus(500);
            return;
        }
        console.log(JSON.stringify(result));
        expressRes.sendStatus(201);
    });
});
module.exports = router;
//# sourceMappingURL=createZendeskUsers.js.map