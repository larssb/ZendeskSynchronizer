<#
    - Script description
    This module invokes a webrequest to the ExpressJS route makeZendeskUserIdentityPrimary. That
    ExpressJS route asks Zendesk to make an identity on a specified user the primary identity.
#>
####################
# FUNCTIONS - PREP
####################
Import-Module -name $PSScriptRoot\zendeskIntegrationConfig -force # Module that configures settings such as vars which is used throughout.

####################
# FUNCTIONS - START
####################
function invoke-makeZendeskUserIdentityPrimaryEndpoint() {
<#
.DESCRIPTION
    This module invokes a webrequest to the ExpressJS route makeZendeskUserIdentityPrimary. That
    ExpressJS route asks Zendesk to make an identity on a specified user the primary identity.

    # Returns
    On success == The response from the makeZendeskUserIdentityPrimary ExpressJS endpoint.
    On failure == $null.
.PARAMETER identityIdInJSON
    The id pointing to the identity to make the primary identity. In JSON!
.EXAMPLE
    $makeIdentityPrimaryWebReqOutput = invoke-makeZendeskUserIdentityPrimaryEndpoint -idOfIdentity $idOfIdentity;
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="The id pointing to the identity to make the primary identity. In JSON!")]
        [ValidateNotNullOrEmpty()]
        $identityIdInJSON
    )
####
# Script execution from here on out
####
    # First control if we have the required variables available
    if( $null -eq (get-variable WebReqURI_makeZendeskUserIdentityPrimary -ErrorAction SilentlyContinue) ) {
        set-makeZendeskUserIdentityPrimary_InvokeWebRequestVars; # This is an exported function in the zendeskIntegrationConfig module - Sets the getZendeskUser ExpressJS route variables
    }

    # Make the call to the ExpressJS endpoint
    try {
        $makeIdentityPrimaryWebReqOutput = Invoke-WebRequest -Uri $WebReqURI_makeZendeskUserIdentityPrimary -Method $WebReqMethod_PUT -Body $identityIdInJSON -ContentType $WebReqContent -ErrorVariable makeIdentityPrimaryErrorVar;
    } catch {
        # Log it with log4net
        $log4netLogger.error("- invoke-makeZendeskUserIdentityPrimaryEndpoint failed with $_");
    }

    # Return
    $makeIdentityPrimaryWebReqOutput;
}

Export-ModuleMember -Function invoke-makeZendeskUserIdentityPrimaryEndpoint;
###################
# FUNCTIONS - END
###################