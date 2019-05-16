/*********************************************************\
    - createZendeskOrgs.ts creates Zendesk organizations -
    It does this from the incoming data. Which is Inventio
    customer AD organizational units.
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
    console.log("- createZendeskOrg invoked -");
    var organization = expressReg.body;
    zendeskClient.organizations.create(organization, function (err, req, result) {
        if (err) {
            console.log(err);
            expressRes.sendStatus(500);
            return;
        }
        var zendeskOrgID = result.id;
        expressRes.status(201).json({ "zendeskOrgId": [zendeskOrgID] });
    });
});
module.exports = router;
//# sourceMappingURL=createZendeskOrg.js.map