################
# Script preparation
################

## ! Load PSSnapins, modules x functions
Import-Module -name $PSScriptRoot\zendeskIntegrationConfig -force # Module that configures settings such as vars which is used throughout.

#####################
# FUNCTION - START
#####################
function get-SubOUsOn...() {
<#
.SYNOPSIS
    Function that retrieves sub-ous from ... AD -- ONLY ... AD! 
.DESCRIPTION
    Function that retrieves sub-ous from ... AD -- ONLY ... AD! 
.PARAMETER enumerator
    A collection enumerator object - containing a company's sub-ou's.  
.PARAMETER srcAD
    Used to specify what the source AD is.  
.PARAMETER syncType
    Used to specify what type of sync is in play.        
.NOTES
#>

# DEFINE PARAMETERS
    param(
        [Parameter(Mandatory=$true, HelpMessage="A collection enumerator object - containing a company's sub-ou's.")]
        [System.Collections.IDictionaryEnumerator]$enumerator,
        [Parameter(Mandatory=$false, HelpMessage="Used to specify what type of sync is in play.")]
        [ValidateNotNullOrEmpty()]        
        $syncType = 'incremental',
        [Parameter(Mandatory=$false, HelpMessage="The DateTime obj. of the last time a sync was a success.")]
        [ValidateNotNullOrEmpty()]
        $lastSync_dateTime
    )

    # Instantiate HASH table to contain both main company OU's and potential sub-company OU's to be synced to Zendesk
    $zendeskOrgOUs = @{};
    if($syncType -eq 'full' -and $null -eq (get-variable DiscardedOUs -ErrorAction SilentlyContinue) ) {
        # HASHtable to store discarded OU's. As we still need users in these later. It will contain OU's whom have the same debitor number but still contains users we need. Therefore duplicates is okay.
        New-variable -name DiscardedOUs -value @{} -Scope 2;
    }

    # Determine company type & gather sub-OU's/companies
    foreach($ou in $enumerator) {    
        if($syncType -eq 'full') {
            set-...Ad_SubOuQueries_Full; # Function in zendeskIntegrationConfig module, used to get AD Query variables defined
        } else {
            # Sync mode is incremental
            set-...Ad_SubOuQueries_Incremental; # Function in zendeskIntegrationConfig module, used to get AD Query variables defined
        }

        # Add the main OU to the $zendeskOrgOUs HASHtable - So that we will have both main & sub-company OU's in the same collected HASH table - In order to get unique companies
        $zendeskOrgOUs.Add($ou.Value.external_id, $ou.value);

        # Query sub-OU's under the main OU - to determine if the customer have any sub-companies
        foreach($subOU in Invoke-Command -ScriptBlock $...subOUs -ArgumentList $ou,$lastSync_dateTime -NoNewScope) {
            # Check if the current sub-OU is already in the HASH table
            if($zendeskOrgOUs.Contains($subOU.external_id) -eq $false) {
                # Add the sub-company OU
                $zendeskOrgOUs.Add($subOU.external_id, $subOU);
            } elseif($syncType -eq 'full') {
                # Save discarded OU's as we need to get any users in these later. We just don't want to create it as an organization in Zendesk because it is not unique to the company.
                $DiscardedOUs.Add($subOU.DistinguishedName, $subOU);                
            }
        };
    };
    
    # Get enumerator so that we can iterate over the Hashtable that contains updated or new companies on AD 
    return $enumerator = $zendeskOrgOUs.GetEnumerator();
}; # End of getSubOUsOn... function declaration

Export-ModuleMember -Function get-SubOUsOn...;
###################
# FUNCTION - END
###################