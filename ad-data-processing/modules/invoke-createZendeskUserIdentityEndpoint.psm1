<#
    - Script description
    This module invokes a webrequest to the ExpressJS route createZendeskUserIdentity. That
    ExpressJS route asks Zendesk to create an identity on a specified user based on the data
    sent to it.
#>
####################
# FUNCTIONS - PREP
####################
Import-Module -name $PSScriptRoot\zendeskIntegrationConfig -force # Module that configures settings such as vars which is used throughout.

####################
# FUNCTIONS - START
####################
function invoke-createZendeskUserIdentityEndpoint() {
<#
.DESCRIPTION
    This module invokes a webrequest to the ExpressJS route createZendeskUserIdentity. That
    ExpressJS route asks Zendesk to create an identity on a specified user based on the data
    sent to it.

    # Returns
    On success == The response from the createZendeskUserIdentity ExpressJS endpoint.
    On failure == $null.
.PARAMETER identityInJSON
    JSON structure containing Zendesk identity data.
.EXAMPLE
    $identityCreationWebReqOutput = invoke-createZendeskUserIdentityEndpoint -identityInJSON $identityInJSON;
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="JSON structure containing Zendesk identity data.")]
        [ValidateNotNullOrEmpty()]
        $identityInJSON
    )
####
# Script execution from here on out
####
    # First control if we have the required variables available
    if( $null -eq (get-variable WebReqURI_createZendeskUserIdentity -ErrorAction SilentlyContinue) ) {
        set-createZendeskUserIdentity_InvokeWebRequestVars; # This is an exported function in the zendeskIntegrationConfig module - Sets the getZendeskUser ExpressJS route variables
    }

    # Make the call to the ExpressJS endpoint
    try {
        $WebReqCreateUserIdentityOutput = Invoke-WebRequest -Uri $WebReqURI_createZendeskUserIdentity -Method $WebReqMethod_POST -Body $identityInJSON -ContentType $WebReqContent -ErrorVariable createUserIdentityErrorVar;
    } catch {
        # Log it with log4net
        $log4netLogger.error("- invoke-createZendeskUserIdentityEndpoint failed with $_");
    }

    # Return
    $WebReqCreateUserIdentityOutput;
}

Export-ModuleMember -Function invoke-createZendeskUserIdentityEndpoint;
###################
# FUNCTIONS - END
###################