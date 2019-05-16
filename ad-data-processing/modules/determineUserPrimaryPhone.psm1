################
# Script preparation
################

## ! Load PSSnapins, modules x functions
Import-Module $PSScriptRoot\zendeskIntegrationConfig.psm1 -force # Module that configures settings such as vars which is used throughout.
Import-Module $PSScriptRoot\getUserOU.psm1 -force
Import-Module $PSScriptRoot\purifyOuDescription.psm1 -force

#####################
# FUNCTION - START
#####################
function determineUserPrimaryPhone() {
<#
.DESCRIPTION
    Helps determine what primary phone number a user on Zendesk should get. The primary phone number is derived from
.PARAMETER adUser
    Used to send in a AD user object which the module uses to determine the OU of the user. Only necessary when using incremental sync.
.PARAMETER srcAD
    Used to specify the AD source.
.PARAMETER compOU
    Dynamic parameter which is used to send in the AD organizationl unit of a company. Used in full sync mode.
.PARAMETER fullSync
    Use this [switch] parameter to specify that the request is based on a full sync.  
.EXAMPLE
.NOTES
#>
    
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="company user has to be specified")]
        [ValidateNotNullOrEmpty()]
        $adUser,
        [Parameter(Mandatory=$true, HelpMessage="Specify which AD is the source")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('','')]
        $srcAD,
        [Parameter(Mandatory=$false, HelpMessage="Switch parameter to define if the request is based on a [FULL SYNC]'.")]
        [Switch]
        $fullSync
    )        

    DynamicParam {
        if($fullSync -eq $true) {
            # Configure parameter
            $attributes = new-object System.Management.Automation.ParameterAttribute;
            $attributes.Mandatory = $false;
            $attributes.HelpMessage = "Organizational unit currently being processed in a full sync.";
            $ValidateNotNullOrEmpty = New-Object Management.Automation.ValidateNotNullOrEmptyAttribute;
            
            # Define parameter collection
            $attributeCollection = new-object -Type System.Collections.ObjectModel.Collection[System.Attribute];
            $attributeCollection.Add($attributes);
            $attributeCollection.Add($ValidateNotNullOrEmpty);
            
            # Prepare to return & expose the parameter
            $ParameterName = "compOU";
            [Type]$ParameterType = "Object";
            $Parameter = New-Object Management.Automation.RuntimeDefinedParameter($ParameterName, $ParameterType, $AttributeCollection);
            if ($psboundparameters.ContainsKey('DefaultValue')) {
                $Parameter.Value = $DefaultValue;
            }
            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary;
            $paramDictionary.Add('compOU', $Parameter);
            return $paramDictionary;
        }
    }        
##
# Script execution from here on out
##
    Begin {};
    Process {
        if($fullSync -ne $true) {
            # Get Organizational unit in which the Primary Group of the user is located. To get the OU description from which we can determine the users primary phone number
            $ou = getUserOU -adUser $adUser -srcAD $srcAD;
        } else {
            $ou = $psboundparameters.compOU; # As we are doing a fullSync we send in the OU directly to this module.
        }
        
        # Incoming AD User object can come both from Hashtable and regularly. Set accordingly.
        if($null -ne $adUser.value.DistinguishedName) {
            $adUserDistinguishedName = $adUser.value.DistinguishedName;
        } else {
            $adUserDistinguishedName = $adUser.DistinguishedName;
        }
        
        # As the ou we work with can come from both a loop over a HASHtable as well as an Array we have to determine which one it is.
        # The OU could also be defined
        if($null -ne $ou.Value.external_id) {
            $OuDescription = $ou.value.external_id;
        } elseif( ($ou | gm).Name.ToLower().contains("external_id".ToLower()) ) {
            $OuDescription = $ou.external_id;
        } elseif( ($ou | gm).Name.ToLower().contains("description".ToLower()) ) {
            $OuDescription = $ou.Description;
        }

        if ($null -ne $adUserDistinguishedName -and $null -ne $OuDescription) {
            if( $null -eq (get-variable ...AdDistinguishedName -ErrorAction SilentlyContinue) ) {
                set-srcAdDistinguishedNameVars # Function in zendeskIntegrationConfig that sets distinguishedname vars for source AD's
            }
            
            # Check that the src AD defined matches the actual user object src AD 
            if($srcAD -eq '' -and $adUserDistinguishedName -match $...AdDistinguishedName) 
            {
                $userPrimaryPhone = $OuDescription;
            } elseif ($srcAD -eq '' -and $adUserDistinguishedName -match $...AdDistinguishedName) {
                # Now determine type of ... customer & set data accordingly
                if( $null -eq (get-variable C5OClassicOuDescriptionRegEx -ErrorAction SilentlyContinue) ) {
                    set-regularExpressionVars; # Function in zendesk config module.
                }
                
                if($OuDescription -match $C5OClassicOuDescriptionRegEx) {
                    # Customer is classic ...
                    $userPrimaryPhone = purifyOuDescription -ouDescription $OuDescription;
                } else {
                    # Customer is Nav app. related customer - Retrieve users primary phone by querying a MSSQL db
                    if( $null -eq (get-variable SQLSrv -ErrorAction SilentlyContinue) ) {
                        set-SQLSrvVars; # Function in zendesk config module.
                    }
                    
                    # Set SQL query vars. Has to be set everytime.
                    set-SQLQueryVars $OuDescription;
                    
                    # Query SQL
                    try {
                        $queryResult = invoke-sqlcmd -serverInstance $SQLSrv -database $SQLDB -username $SQLUser -password $SQLPass -query $query_determineNavUserPrimaryPhone -QueryTimeout $SQLQuery_timeout -HostName $SQLQueryExecutingHost -ErrorVariable $queryResultErrorVariable;
                    } catch {
                        # Log it with log4net 
                        $log4netLogger.error("a) determineUserPrimaryPhone() | Querying SQL to determine user primary phone failed with: $_ : The query was: $query_determineNavUserPrimaryPhone");        
                        $log4netLogger.error("b) determineUserPrimaryPhone() | SQL query call Ps error variable: $queryResultErrorVariable");
                    }
                    # Check & pull out the result
                    if($queryResult.ACCOUNT.length -ge 1) {                               
                        [array]$userPrimaryPhone = $queryResult.ACCOUNT.Trim(); # Get the account number (represents a company's primary phone num.). Need to remove whitespace as well with Trim()
                    } else {
                        # Log it with log4net 
                        $log4netLogger.error("determineUserPrimaryPhone() | Querying SQL to determine user primary phone didn't return any results.");        
                    }
                }           
            } else {
                # Log it with log4net 
                $log4netLogger.error("determineUserPrimaryPhone() | AD SRC OR AD user DistinguishedName could not be determined. User primary phone not defined!");
                throw "determineUserPrimaryPhone() | AD SRC OR AD user DistinguishedName could not be determined. User primary phone not defined!";
                break;
            }
            
            # Return
            return $userPrimaryPhone;
        } else {
            # Throw error that necessary data could not be derived in order to determine a user primary phone.
            throw "determineUserPrimaryPhone() failed | no data in OU description var or adUser distinguishedname. Vlues: (OuDescription): $OuDescription - (adUserDistinguishedName): $adUserDistinguishedName.";
        } # End of condition control on $oudescription and $adUserDistinguishedName
    } # End of Process statement
    End {}
}

Export-ModuleMember -Function determineUserPrimaryPhone;
###################
# FUNCTION - END
###################