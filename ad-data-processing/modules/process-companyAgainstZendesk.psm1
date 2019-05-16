################
# Script preparation
################

## ! Load PSSnapins, modules x functions
Import-Module -name $PSScriptRoot\zendeskIntegrationConfig -force # Module that configures settings such as vars which is used throughout.
Import-Module -name $PSScriptRoot\determineCompanyTypeTagIt -force
Import-Module -name $PSScriptRoot\transformOuDescriptionToJSON -force
Import-Module -name $PSScriptRoot\transformOuToJSON -force

#####################
# FUNCTION - START
#####################
function process-companyAgainstZendesk() {
<#
.DESCRIPTION
    Function that processes a company against Zendesk to determine if it should be [updated] or [created]. Used for both [full] & [incremental] sync     
.PARAMETER $ou
    A company AD organizational unit.
.PARAMETER $srcAD  
    Used to specify the source of the AD for which data is being processed.              
.NOTES
#>

# DEFINE PARAMETERS
    param(
        [Parameter(Mandatory=$true, HelpMessage="A company AD organizational unit.")]
        [ValidateNotNullOrEmpty()]
        $ou,
        [Parameter(Mandatory=$true, HelpMessage="Used to specify the source of the AD for which data is being processed.")]
        [ValidateNotNullOrEmpty()]        
        $srcAD
    )
# PREPARE FUNCTION
    # Set Invoke-WebRequest variables if they are not already available.
    if( $null -eq (get-variable WebReqURI_getZendeskOrganization -ErrorAction SilentlyContinue) ) {
        set-getZendeskOrganization_InvokeWebRequestVars; # Function in zendeskIntegrationConfig module, used to define getZendeskOrganization web request vars
        set-updateZendeskOrg_InvokeWebRequestVars; # Function in zendeskIntegrationConfig module, used to define updateZendeskOrg web request vars
        set-createZendeskOrg_InvokeWebRequestVars; # Function in zendeskIntegrationConfig module, used to define createZendeskOrg web request vars
    }        
# RUN
    # Try to get the company on Zendesk. By querying the Zendesk REST API.
    $ouDescriptionInJSON = transformOuDescriptionToJSON -ou $ou;
    
    try {        
        $WebReqGetZendeskOrgOutput = Invoke-WebRequest -Uri $WebReqURI_getZendeskOrganization -Method $WebReqMethod_POST -Body $ouDescriptionInJSON -ContentType $WebReqContent -ErrorVariable getZendeskOrganizationReqError;
    } catch {
        # Log it with log4net
        $log4netLogger.error("a) process-companyAgainstZendesk() | Invoke Web request failed on: WebReqURI_getZendeskOrganization, with: $_");        
        $log4netLogger.error("b) process-companyAgainstZendesk() | getZendeskOrganization call Ps error variable: $getZendeskOrganizationReqError");
    }
    
    # Check if the company exists as an Zendesk Org.: if it does update it <--> if not create the company on Zendesk.
    if(!$getZendeskOrganizationReqError) {
        # No error occurred trying to get a Zendesk org. Check if HTTP200 OK was the response.
        if($WebReqGetZendeskOrgOutput.StatusCode -eq 200) {        
            <####
             - Company found --> But we are not interested in updating it. All we update is the OU name to Zendesk org. name.
             - Only log that the company already exists on Zendesk and do no more.   
            ####>            
            # Log it with log4net            
            $log4netLogger.error("process-companyAgainstZendesk() | Company found to already be existing on Zendesk. Do no more....");            
            
            # Retrieve Zendesk data on the company
            [string]$companyZendeskOrgID = (ConvertFrom-Json -InputObject $WebReqGetZendeskOrgOutput.Content).zendeskOrgId; # Retrieved so that we can update exact organization

            # The organization was successfully updated
            return $companyZendeskOrgID;            
                        
        <#
            ####
            ## Company found --> [update] it
            ####
            
            # Retrieve Zendesk data on the company
            [string]$companyZendeskOrgID = (ConvertFrom-Json -InputObject $WebReqGetZendeskOrgOutput.Content).zendeskOrgId; # Retrieved so that we can update exact organization
            
            # Get OU data transformed to JSON
            $OUinJSON = transformOuToJSON -ou $ou -transformType 'update' -zendeskOrgID $companyZendeskOrgID;
            
            try {
                # PUT the JSON data to the ExpressJS updateZendeskOrg server endpoint - to have it try updating the organization
                $WebReqUpdateZendeskOrgOutput = Invoke-WebRequest -Uri $WebReqURI_updateZendeskOrg -Method $WebReqMethod_PUT -Body $OUinJSON -ContentType $WebReqContent -ErrorVariable updateZendeskOrgReqError;
                
                # Check if the org. was [UPDATED] successfully
                if($WebReqUpdateZendeskOrgOutput.StatusCode -eq 200) {
                    # The organization was successfully updated
                    return $companyZendeskOrgID;
                } else {
                    # Log it with log4net
                    $log4netLogger.error("a) process-companyAgainstZendesk() | The status code on WebReqUpdateZendeskOrgOutput was different from HTTP200. Unknown state, cannot continue.");
                    $log4netLogger.error("b) process-companyAgainstZendesk() | The status code returned is: $($WebReqUpdateZendeskOrgOutput.StatusCode).");
                    throw "process-companyAgainstZendesk() | The statusCode on WebReqUpdateZendeskOrgOutput was different from 200OK. Unknown state, cannot continue."
                }
            } catch {
                # Log it with log4net
                $log4netLogger.error("a) process-companyAgainstZendesk() | Invoke Web request failed on: WebReqURI_updateZendeskOrg, with: $_");        
                $log4netLogger.error("b) process-companyAgainstZendesk() | updateZendeskOrg call Ps error variable: $updateZendeskOrgReqError");
            }
        #>
        
        } else {
            # Log it with log4net            
            $log4netLogger.error("a) process-companyAgainstZendesk() | The status code on WebReqGetZendeskOrgOutput was different from HTTP200. Unknown state, cannot continue.");
            $log4netLogger.error("b) process-companyAgainstZendesk() | The status code returned is: $($WebReqGetZendeskOrgOutput.StatusCode).");
            throw "process-companyAgainstZendesk() | The status code on WebReqGetZendeskOrgOutput was different from 200OK. Unknown state, cannot continue."
        }
    } elseif($getZendeskOrganizationReqError.message -match 'No Zendesk org found with specified ID') {
        ####
        ## Company does not exist --> [create] it / The org. was not found. HTTP404 (Item not found) was returned.
        ####
        
        # Remove the $getCompanyZendeskOrgIDReqError variables in order to ensure we do not get unexpectedly into the if check on the var. above.
        Remove-Variable getZendeskOrganizationReqError;
        
        # Determine type of company (customer) & add info to OU object. Also checking for this when doing [INCREMENTAL] sync as company type could have changed.
        $ou = determineCompanyTypeTagIt -ou $ou -srcAD $srcAD;
        
        # Send incoming ou to Ps module/function that tranform the data to JSON
        if($srcAD -eq $...IsAD) {
            $OUinJSON = transformOuToJSON -ou $ou -transformType 'create';
        } else {
            $OUinJSON = transformOuToJSON -ou $ou -transformType 'create' -srcAdIs...;
        }
        
        try {
            # POST the JSON data to the ExpressJS createZendeskOrgs server endpoint - to have it request for the Company to be created on Zendesk.
            $WebReqCreateZendeskOrgOutput = Invoke-WebRequest -Uri $WebReqURI_createZendeskOrg -Method $WebReqMethod_POST -Body $OUinJSON -ContentType $WebReqContent -ErrorVariable createZendeskOrgReqError;
    
            # Check if the org. was [CREATED] successfully
            if($WebReqCreateZendeskOrgOutput.StatusCode -eq 201) {
                # Log it with log4net
                $log4netLoggerDebug.debug("process-companyAgainstZendesk | CREATE Company | It was successfully created.");                
                
                # The organization was successfully created - Retrieve Zendesk data on the company
                [string]$companyZendeskOrgID = (ConvertFrom-Json -InputObject $WebReqCreateZendeskOrgOutput.Content).zendeskOrgId; # Retrieved so that we can for example create users under exact Zendesk organization
                return $companyZendeskOrgID;
            } else {
                # Log it with log4net
                $log4netLogger.error("a) process-companyAgainstZendesk() | The statusCode on WebReqCreateZendeskOrgOutput was different from HTTP201. Unknown state, cannot continue.");
                $log4netLogger.error("b) process-companyAgainstZendesk() | The status code returned is: $($WebReqCreateZendeskOrgOutput.StatusCode).");
                throw "process-companyAgainstZendesk() | The statusCode on WebReqCreateZendeskOrgOutput was different from 201CREATED. Unknown state, cannot continue."
            }            
        } catch {
            # Log it with log4net
            $log4netLogger.error("a) process-companyAgainstZendesk() | createZendeskOrg failed with: $_");
            $log4netLogger.error("b) process-companyAgainstZendesk() | createZendeskOrg call Ps error variable: $createZendeskOrgReqError");
        }
    }
}; # End of process-companyAgainstZendesk function declaration

Export-ModuleMember -Function process-companyAgainstZendesk;
###################
# FUNCTION - END
###################