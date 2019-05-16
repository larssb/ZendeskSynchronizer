#####################
# FUNCTION - START
#####################
function determineUserModifiedStatus() {
<#
.DESCRIPTION
    This helper function/module helps us determine if an incoming AD user has been modified in such a way which makes us interested in updating
	the user to Zendesk. Or possibly create the user if it was recently activated.

    - Return $null if the user wasn't modified on the control data.
.PARAMETER user
    Should be an AD user object.
.PARAMETER lastSync_dateTime
    A DateTime object containing the last time an incremental sync was performed.
.PARAMETER srcDomain
    The source domain in AD.
.PARAMETER controlEmailOnly
    Switch to specify that only the users e-mail should be controlled for its modification status.        
.EXAMPLE
.NOTES
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="A user AD object.")]
        [ValidateNotNullOrEmpty()]
        $user,
        [Parameter(Mandatory=$true, HelpMessage="The DateTime of the last incremental sync.")]
        [ValidateNotNullOrEmpty()]
        $lastSync_dateTime,
        [Parameter(Mandatory=$true, HelpMessage="The source domain in AD.")]
        [ValidateNotNullOrEmpty()]
        $srcDomain,
        [Parameter(Mandatory=$false, HelpMessage="Switch to specify that only the users e-mail should be controlled for its modification status.")]
        [ValidateNotNullOrEmpty()]
        [switch]$controlEmailOnly                       
    )
##
# Script execution from here on out
##
    # Set vars based on incoming data
    $domain = $srcDomain;
    $acct = $user;

    # Define the object that will let us retrieve AD replication data
    $ObjectDN = $Acct.DistinguishedName;
    $context = new-object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain", $domain);
    $oDC = [System.DirectoryServices.ActiveDirectory.DomainController]::findOne($context);
    $meta = $oDC.GetReplicationMetadata($objectDN);

    # Retrieve the data for the AD attributes we are interested in knowing if are updated
    $nameOfUserModifiedStatus = $meta.name.LastOriginatingChangeTime;
    $emailOfUserModifiedStatus = $meta.mail.LastOriginatingChangeTime;
    $mobileOfUserModifiedStatus = $meta.mobile.LastOriginatingChangeTime;
    $userAccountControlOfUserModifiedStatus = $meta.useraccountcontrol.LastOriginatingChangeTime;

    if ($controlEmailOnly) {
        if($emailOfUserModifiedStatus -gt $lastSync_dateTime -and $acct.whenCreated -lt $lastSync_dateTime) {
            $userStatus = 'Modified';
        }        
    } else {
        # Now check if the user was really modified on AD attributes we are interested in
        [string]$userStatus = '';
        if($nameOfUserModifiedStatus -gt $lastSync_dateTime -and $acct.whenCreated -lt $lastSync_dateTime) {
            $userStatus = 'Modified';
        }
        
        if($emailOfUserModifiedStatus -gt $lastSync_dateTime -and $acct.whenCreated -lt $lastSync_dateTime) {
            $userStatus = 'Modified';
        }
        
        if($mobileOfUserModifiedStatus -gt $lastSync_dateTime -and $acct.whenCreated -lt $lastSync_dateTime) {
            $userStatus = 'Modified';
        }
        
        if($userAccountControlOfUserModifiedStatus -gt $lastSync_dateTime -and $acct.whenCreated -lt $lastSync_dateTime) {
            $userStatus = 'Activated';
        }
    }
    
    # Return the result
    return $userStatus;
} # End of function declaration

Export-ModuleMember -Function determineUserModifiedStatus;
###################
# FUNCTION - END
###################