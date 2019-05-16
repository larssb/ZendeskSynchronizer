/******************************************************\
	- zendeskClient instantiate a Zendesk client -	
/******************************************************/

/* LOAD MODULES */
var zendesk = require('node-zendesk');

/* MODULE CONFIGURATION */

// Define the production Zendesk client.
var prodZendeskClient = zendesk.createClient({
	username: '',
	token: '',
	remoteUri: 'https://SUB-DOMAIN_NAME.zendesk.com/api/v2'
});

// Define the sandbox Zendesk client.
var sandboxZendeskClient = zendesk.createClient({
	username: '',
	token: '',
	remoteUri: 'https://SANDBOX-SUB-DOMAIN.zendesk.com/api/v2'
});

/*
- Determine whether Node was started in sandbox or production mode. Run modes have been defined in package.json.
*/ 
var isSandboxMode = process.env.NODE_ENV && process.env.NODE_ENV.indexOf('sandbox') !== -1 ? true : false;

if (isSandboxMode === true) {
    var zendeskClient = sandboxZendeskClient;
} else {
    var zendeskClient = prodZendeskClient;
}

module.exports = zendeskClient;