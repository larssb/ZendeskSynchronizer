/*********************************************************\
    - updateZendeskOrgs.ts updates a Zendesk organization -
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
    .put(parsePayload, function (expressReg, expressRes) {
    console.log(" ----- ");
    console.log("- updateZendeskOrg invoked -");
    var organization = expressReg.body.orgToZendesk;
    var organizationID = expressReg.body.organizationID;
    zendeskClient.organizations.update(organizationID, organization, function (err, req, result) {
        if (err) {
            console.log(err);
            expressRes.sendStatus(500);
            return;
        }
        var zendeskOrgID = result.id;
        expressRes.status(200).json({ "zendeskOrgId": [zendeskOrgID] });
    });
});
module.exports = router;
//# sourceMappingURL=updateZendeskOrg.js.map