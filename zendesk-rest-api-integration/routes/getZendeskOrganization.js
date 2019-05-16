/*********************************************************\
    - getZendeskOrganization.ts queries Zendesk for
    an Zendesk organizations.
    It does this by querying Zendesk based on an unique
    identificator. GUID/K on O environements and debitor number
    on HD.
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
    console.log("- getZendeskOrganization invoked -");
    var companyExternalID = expressReg.body;
    console.log("Company external ID retrieved: " + companyExternalID.external_id);
    zendeskClient.organizations.search(companyExternalID, function (err, req, result) {
        if (err) {
            console.log(err);
            expressRes.sendStatus(500);
            return;
        }
        if (result !== null && result.length > 0) {
            var zendeskOrgID = result[0].id;
            var zendeskOrgName = result[0].name;
            expressRes.status(200).json({ "zendeskOrgId": [zendeskOrgID],
                "zendeskOrgName": [zendeskOrgName] });
            return;
        }
        else {
            expressRes.status(404).json("No Zendesk org found with specified ID");
            return;
        }
    });
});
module.exports = router;
//# sourceMappingURL=getZendeskOrganization.js.map