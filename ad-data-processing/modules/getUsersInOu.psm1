################
# Script preparation
################

## ! Load PSSnapins, modules x functions
Import-Module $PSScriptRoot\zendeskIntegrationConfig.psm1 -force # Module that configures settings such as vars which is used throughout.

#####################
# FUNCTION - START
#####################
function getUsersInOu() {
<#
.DESCRIPTION
    This module gets users in the OU sent into the module. Used for 'full' type of sync only. It returns users as a hashtable collection to the caller.
.PARAMETER ou
    The OU which should be queried for users.
.PARAMETER srcAD
    Used to define which AD is the source of the request.     
.EXAMPLE
.NOTES
#>
	# Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="Organizational unit that should be queried for users.")]
        [ValidateNotNullOrEmpty()]
        $ou,
        [Parameter(Mandatory=$true, HelpMessage="The source AD which the Zendesk Integration system should process AD objects from.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('','')]
        $srcAD
    )
##
# Script execution from here on out
##
    # As the incoming ou can both come from a loop over a HASHtable as well as an Array we have to determine which one
    if($null -ne $ou.Value.DistinguishedName) {
        $DistinguishedName = $ou.value.DistinguishedName;
    } else {
        $DistinguishedName = $ou.DistinguishedName;
    }

    # Before trying to set srcAdDistinguishedNameVars check if they haven't already been set
    if( $null -eq (get-variable ...AdDistinguishedName -ErrorAction SilentlyContinue) ) {
        # Determine which AD is the source AD
        set-srcAdDistinguishedNameVars # This is an exported function in the zendeskIntegrationConfig module - Configures the DinstinguishedName variables as we have multiple domains in play
    }
    
    # Set $GetActiveAndRegularUsers var.
    if($srcAD -eq '' -and $DistinguishedName -match $...AdDistinguishedName) {   
        # As the incoming ou can both come from a loop over a HASHtable as well as a Array we have to determine which one

        # Before trying to set ...AdOuQueries_Users_Full vars check if they haven't already been set
        if( $null -eq (get-variable ...Users_HashBased_Full -ErrorAction SilentlyContinue) ) {
            set-...AdOuQueries_Users_Full # This is an exported function in the zendeskIntegrationConfig module
        }
        
        if($null -ne $ou.Value.DistinguishedName) {
            $GetActiveAndRegularUsers = $...Users_HashBased_Full;
        } else {
            $GetActiveAndRegularUsers = $...Users_ArrayBased_Full;
        }
    } elseif($srcAD -eq '' -and $DistinguishedName -match $...AdDistinguishedName) {
        # As the incoming ou can both come from a loop over a HASHtable as well as a Array we have to determine which one
        
        # Before trying to set ...Users_HashBased_Full vars check if they haven't already been set
        if( $null -eq (get-variable ...Users_HashBased_Full -ErrorAction SilentlyContinue) ) {
            set-...AdOuQueries_Users_Full; # This is an exported function in the zendeskIntegrationConfig module
        }
        
        if($null -ne $ou.Value.DistinguishedName) {
            $GetActiveAndRegularUsers = $...Users_HashBased_Full;
        } else {
            $GetActiveAndRegularUsers = $...Users_ArrayBased_Full;
        }
    }

    # Get Users - In the incoming OU
    [array]$users = @();
    foreach($user in Invoke-Command -ScriptBlock $GetActiveAndRegularUsers -ArgumentList $ou -NoNewScope) {
        if($srcAD -eq '') {
            $userPropertyAdjusted = $user | Select-object name,@{Name="email";Expression={$_.mail}},mobile,@{Name="external_id";Expression={$_.ObjectGUID.ToString()}},DistinguishedName,department;
        } elseif($srcAD -eq '') {
            $userPropertyAdjusted = $user | Select-object name,@{Name="email";Expression={$_.mail}},mobile,@{Name="external_id";Expression={$_.SID.ToString()}},DistinguishedName;
        }
        $users += $userPropertyAdjusted;
    }

    # Return users as a hashtable collection to the caller.
    return $users;
}

Export-ModuleMember -Function getUsersInOu;
###################
# FUNCTION - END
###################