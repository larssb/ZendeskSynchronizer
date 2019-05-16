<#
.SYNOPSIS
    This helper function/module helps us determine if an incoming AD OU has been modified in such a way which makes us interested in updating
	the company to Zendesk.
.DESCRIPTION
    This helper function/module helps us determine if an incoming AD OU has been modified in such a way which makes us interested in updating
	the company to Zendesk
.PARAMETER OU
    Should be an AD organizational unit object.
.PARAMETER lastSync_dateTime
    A DateTime object containing the last time an incremental sync was performed.
.EXAMPLE
.NOTES
#>
#####################
# FUNCTION - START
#####################
function determineCompanyModifiedStatus() {
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="An OU AD object.")]
        [ValidateNotNullOrEmpty()]
        $ou,
        [Parameter(Mandatory=$true, HelpMessage="The DateTime of the last incremental sync.")]
        [ValidateNotNullOrEmpty()]
        $lastSync_dateTime,
        [Parameter(Mandatory=$true, HelpMessage="Info on the AD source.")]
        [ValidateNotNullOrEmpty()]
        $srcDomain               
    )
##
# Script execution from here on out
##
    # Set vars based on incoming data
    $domain = $srcDomain;
    $container = $ou.value; # .value as we are working with an OU obj. in a HASHtable collection.

    # Define the object that will let us retrieve AD replication data
    $ObjectDN = $container.DistinguishedName;
    $context = new-object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain", $domain);
    $oDC = [System.DirectoryServices.ActiveDirectory.DomainController]::findOne($context);
    $meta = $oDC.GetReplicationMetadata($objectDN);
    
    # Retrieve the data for the AD attributes we are interested in knowing if are updated
    $nameOfOuModifiedStatus = $meta.name.LastOriginatingChangeTime
    
    # Now check if the OU was really modified on AD attributes we are interested in
    [string]$companyStatus = '';
    if($nameOfOuModifiedStatus -gt $lastSync_dateTime) {
        $companyStatus = 'Modified';
    }
    
    # Return the result
    return $companyStatus;
} # End of function declaration

Export-ModuleMember -Function determineCompanyModifiedStatus;
###################
# FUNCTION - END
###################