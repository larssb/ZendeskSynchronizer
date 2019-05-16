::::OVERALL::::

    // STRUCTURE EXPLAINED
        //// Organizations AKA Companies
    1. Type of sync (FULL or INCREMENTAL) is determined by the existense of the file 'syncData.dat' in 'ProcessDataFromADs\data
        1a. If the file does not exist a FULL sync will be performed & vice versa.
        
        //// Users
    1. When the sync mode is 'incremental' and a user is found to have been modified on a source AD. The user should be updated on Zendesk as well. This is how: We look at certain AD
    attributes we are interested in knowing if have been updated. Is just one updated we update the user. When updating we just send all the user data to Zendesk basically overwritting data
    that are the same but also updating data from AD to Zendesk that has been changed. This is the easiest and cleanest way and the JSON payload is very small so should be ok.  

::::Data validity::::
    1. User e-mail data: If an on-prem AD users e-mail has been updated this will take precedence over Zendesk IF the e-mail is 
    different from Zendesk! 

::::AD Data gathering::::
    
	-- ASSUMPTIONS --
    1. ... Companies only have one-level sub-companies in AD. Meaning: 'main OU' --> '1 or * sub-companies' directly underneath the main OU.
        1a. If there is any OU's below the second level they will not contain regular users for whom we would be interested in including on Zendesk
    2. If several OU's have the same debitor number it is assumed that the users within these OU's belongs to the same company.
    3. There will never be a sub-ou that contains OLD* in its name.
        3a. In other words it should therefore be safe to search deeper than one level when looking for filtered & discarded OU's (to get users in these).
    4. When gathering phone number for users we use the primary group location to gather a relevant OU. For the ... AD it is then neccessary that all
    OU's containing users we want to be on Zendesk, have a usefull description.  
    5. User primary phone is never changed. As a users primary phone is their companies main phone. Therefore no need to update this when a user has been modified or activated
    and is already on Zendesk.
    6. Primary group location is closest/most relevant in relation to customer OU that has a description we want.
    7. On the ... environment it is a rule of thumb that no regular customer users can be a member of 'Domain Users'. We therefore filter
    on this, when retrieving users on ... AD for our incremental sync runs.
    On ... this is not neccessary as our AD query searchbase is 'Terminal Users' and we therefore do not get a lot of unwanted users.
    Besides, all users on ... is a member of 'Domain Users'. So no can do!

	-- Methods used to adhere to the above stated assumptions & other issues of importance --
    1. NoZendeskOrg tag on an OU to filter that OU. So that it is not created as an Zendesk organization.
    2. DoCreateZendeskUsers tag on OU's to specifically include OU's that might previously have been filtered. To be considered as a way to whitelist an OU to get its users included in the Zendesk integration sync.
    3. The order of sync is important. Always do OU's to orgs first --> then users into orgs

    :::: Notes on specific sync corner cases ::::
    1. Non-active users that becomes active is synced to Zendesk as this will have modified the user. As we look on the useraccountcontrol AD attribute.
    If this has been changed since last time of incremental sync and we got the user in our AD query in the first place (we only get active users), we are pretty sure that
    the user was just enabled. 
    2. We can not handle a user moving from one company on ... or ... to another. This move have to be made on Zendesk.
    3. srcAD variable options are: ... && ...
        3a. ... == Hosted Desktop environment AD
        3b. ... == NAVOnline && C5Online AD
    4. Companies will be created even though no users are applicable for being updated or created on Zendesk.
    
    -- Running the PowerShell main script --
    1. On ... the srv running the Ps main script is: c5batch01
    2. On ... the srv running the Ps main script is: batch04

::::NodeJS - ExpressJS Framework::::
    WHAT IS IT: ExpressJS is a webserver framework running on NodeJS.
    
    Test server: outest08
    Production server: batch04
    Note: 1 server for both AD's. 
    
::::Zendesk::::
    Overview: There is two environments on Zendesk that can be synced to. SUB-DOMAIN.zendesk.com and a sandbox environemt 'x'.zendesk.com.
        -- SUB-DOMAIN.zendesk.com is used for production and should not be used for testing or demoing new features.
        -- 'x'.zendesk.com should be used for testing, demoing and so forth. The actual pre-fix to .zendesk.com can be found under SUB-DOMAIN.zendesk.com account.
    Technical: Each Zendesk environment has a matching API token which is used when connecting to the environment.
        -- The label of the token for each environment is: SUB-DOMAINZendeskDev 
    Users: The user that is used to connect and communicate with Zendesk can be the same for all environments. 
    
    // When resetting a Zendesk Sandbox \\
    
    1. Set API again
        - Define a new token. Name it: SUB-DOMAINZendeskDev
    2. Set the mobile user field.
        - Settings in Zendesk --> User Fields --> Text field --> mobile in both fields.
        - Description: Custom field for storing a users mobile number.
    3. Get new endpoint URI of sandbox.
        - example: 'https://SANDBOX-SUB-DOMAIN.zendesk.com/api/v2'
    4. Insert data into zendeskClient.ts under Y:\Zendesk\Sourcecode\MiddlemanEndpoint\zendesk:
        - Endpoint URI.
        - API token named; SUB-DOMAINZendeskDev
    5. Compile TS to JS (Ctrl-shift-b in Visual Studio Code)
    6. Restart NodeJS server.
        - rerun NodeJS with: npm test              

::::Differences between running the system on ... & ...::::
    1. ... requires editing the Windows hosts file because the NodeJS servers are part of the ASP.PROCOM domain.       