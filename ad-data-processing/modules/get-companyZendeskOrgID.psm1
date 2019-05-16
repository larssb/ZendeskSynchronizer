################
# Script preparation
################

## ! Load PSSnapins, modules x functions
Import-Module $PSScriptRoot\zendeskIntegrationConfig.psm1 -force # Module that configures settings such as vars which is used throughout.
Import-Module $PSScriptRoot\transformOuDescriptionToJSON.psm1 -force;

#####################
# FUNCTION - START
#####################
function get-companyZendeskOrgID() {
<#
.SYNOPSIS
    Retrieves a company's Zendesk organization ID. 
.DESCRIPTION
    Retrieves a company's Zendesk organization ID.
.PARAMETER OU
    The organizational unit to base the request to Zendesk on. For retrieving the company's Zendesk org. ID.
.EXAMPLE
    get-companyZendeskOrgID -ou $ou
.NOTES
#>
    
# DEFINE PARAMETERS
    param(
        [Parameter(Mandatory=$true, HelpMessage="A company organizational unit.")]
        [ValidateNotNullOrEmpty()]
        $ou
    )
# PREPARE FUNCTION
    if( $null -eq (get-variable WebReqURI_getZendeskOrganization -ErrorAction SilentlyContinue) ) {
        # Set Invoke-WebRequest as this is the first time we load the zendeskIntegrationConfig module
        set-getZendeskOrganization_InvokeWebRequestVars;
    }
# RUN    
    $ouDescriptionInJSON = transformOuDescriptionToJSON -ou $ou;

    try {
        # Get the org. id by querying the Zendesk RESP API.
        $WebReqGetZendeskOrgOutput = Invoke-WebRequest -Uri $WebReqURI_getZendeskOrganization -Method $WebReqMethod_POST -Body $ouDescriptionInJSON -ContentType $WebReqContent -ErrorVariable getZendeskOrgOutputReqError;
    } catch {
        # Log it with log4net
        $log4netLogger.error("a) get-companyZendeskOrgID() | Invoke Web request failed on: WebReqURI_getZendeskOrganization, with: $_");        
        $log4netLogger.error("b) get-companyZendeskOrgID() | getZendeskOrganization call Ps error variable: $getZendeskOrgOutputReqError");        
    }
    
    # Check if the org. ID was successfully retrieved - IF SO - return the Zendesk Org. ID. 
    if(!$getZendeskOrgOutputReqError) {
        # No error occurred trying to get the Zendesk org. Check if HTTP200 OK was the response.        
        if($WebReqGetZendeskOrgOutput.StatusCode -eq 200) {
            # The organization was successfully retrieved - pull out the Zendesk org. id it got assigned from the response content
            [string]$companyZendeskOrgID = (ConvertFrom-Json -InputObject $WebReqGetZendeskOrgOutput.Content).zendeskOrgId;
        
            return $companyZendeskOrgID;
        } else {
            # Log it with log4net
            $log4netLogger.error("get-companyZendeskOrgID() | getZendeskOrganization call failed, no company Zendesk org. ID was retrieved. Ps error variable: $getZendeskOrgOutputReqError");        
        }
    }
}; # End of  function declaration

Export-ModuleMember -Function get-companyZendeskOrgID;
###################
# FUNCTION - END
###################