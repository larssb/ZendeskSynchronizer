/*********************************************************\
    - updateZendeskUsers.ts updates Zendesk users -
    It does this from the incoming JSON data. This data is
    incoming AD users from the different source AD's in play.
/*********************************************************/
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
    console.log("- updateZendeskUsers invoked -");
    var users = expressReg.body;
    console.log(users);
    zendeskClient.users.updateMany(users, function (err, req, result) {
        if (err) {
            console.log(err);
            expressRes.sendStatus(500);
            return;
        }
        console.log(JSON.stringify(result));
        expressRes.sendStatus(200);
    });
});
module.exports = router;
//# sourceMappingURL=updateZendeskUsers.js.map