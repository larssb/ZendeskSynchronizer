################
# Script preparation
################

#####################
# FUNCTION - START
#####################
function confirm-shouldUserBeIncluded() {
<#
.DESCRIPTION
    Helper module that helps determine if an AD user should be included. Acts as a filtering function to exclude e.g.
    service users and other users you might not want to synchronize to Zendesk
.PARAMETER srcAD
    With this parameter you define the source AD of the user AD object.
.PARAMETER user
    The AD user object that should be checked upon inclusion or exclusion.
.EXAMPLE
    confirm-shouldUserBeIncluded -srcAd $srcAD -user $adUser
.NOTES
#>
    
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="Used to define the AD source.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('','')]        
        $srcAD,
        [Parameter(Mandatory=$true, HelpMessage="AD user object.")]
        [ValidateNotNullOrEmpty()]
        $adUser
    )
##
# Script execution from here on out
##
    [boolean]$userOk = $false;
    # If AD source is ... we have to check the retrieved users again to filter out unwanted users
    if($srcAD -eq '') {
        if($null -eq $adUser.department -or $adUser.DistinguishedName -match '') {
            $userOk = $true;
        } 
    } elseif($srcAD -eq '') {
        # If AD source is ... we have to run through retrieved users again to filter out unwanted users.
        if($adUser.DistinguishedName -notmatch '') {
            $userOk = $true;
        } 
    }
    
    # Return the result
    return $userOk;    
}

Export-ModuleMember -Function confirm-shouldUserBeIncluded;
###################
# FUNCTION - END
###################