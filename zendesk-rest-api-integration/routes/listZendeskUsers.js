/*********************************************************\
    - listZendeskUsers.ts lists Zendesk users -
    It does this by querying for users that exists underneath
    a specific Zendesk organization ID (which represents an
    Inventio.iT customer).
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
    console.log("- listZendeskUsers invoked -");
    var companyZendeskOrgID = expressReg.body;
    console.log("CompanyZendeskOrgID retrieved: " + companyZendeskOrgID);
    zendeskClient.users.listByOrganization(companyZendeskOrgID, function (err, req, result) {
        if (err) {
            console.log(err);
            expressRes.sendStatus(500);
            return;
        }
        var userList = result;
        expressRes.status(200).json(userList);
    });
});
module.exports = router;
//# sourceMappingURL=listZendeskUsers.js.map