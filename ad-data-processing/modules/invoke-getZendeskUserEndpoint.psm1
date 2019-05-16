####################
# FUNCTIONS - PREP
####################
Import-Module -name $PSScriptRoot\zendeskIntegrationConfig -force # Module that configures settings such as vars which is used throughout.
Import-Module -name $PSScriptRoot\3rdParty\ExecutionInfo -Force

####################
# FUNCTIONS - START
####################
function invoke-getZendeskUserEndpoint() {
<#
.DESCRIPTION
    This module invokes a webrequest to the ExpressJS route getZendeskUser. That ExpressJS route asks Zendesk 
    to get a specific user on Zendesk.    

    - Returns
    on success = the Zendesk user in JSON.
    on failure = It throws an error to caller.
.PARAMETER userUniqueIDInJSON
.EXAMPLE
    $WebReqGetUserOutput = invoke-getZendeskUserEndpoint -userUniqueIDInJSON $userUniqueIDInJSON;
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="The users external_id which is SID or ObjectGUID depending on the AD.")]
        [ValidateNotNullOrEmpty()]
        $userUniqueIDInJSON
    )
####
# Script execution from here on out
####
    try {
        if( $null -eq (get-variable WebReqURI_getZendeskUser -ErrorAction SilentlyContinue) ) {
            set-getZendeskUser_InvokeWebRequestVars # This is an exported function in the zendeskIntegrationConfig module - Sets the getZendeskUser ExpressJS route variables
        }

        # Try to retrieve the user from Zendesk.
        $WebReqGetUserOutput = Invoke-WebRequest -Uri $WebReqURI_getZendeskUser -Method $WebReqMethod_POST -Body $userUniqueIDInJSON -ContentType $WebReqContent;
    } catch {
        # Get data of execution context, in order to know info on caller and ease troubleshooting
        $ExecutionInfo = Get-execution; 

        # Log it with log4net
        $log4netLogger.error("a) invoke-getZendeskUserEndpoint | Invoke Web request failed on: $WebReqURI_getZendeskUser, with: $_");        
        $log4netLogger.error("b) invoke-getZendeskUserEndpoint | Execution flow: $($ExecutionInfo.command) - Call references: $($ExecutionInfo.location).");
    
        # Throw error to caller
        throw "- Failed getting the user on Zendesk, with: $_";
    }

    # Return
    $WebReqGetUserOutput; 
}

Export-ModuleMember -Function invoke-getZendeskUserEndpoint;
###################
# FUNCTIONS - END
###################