#####################
# FUNCTION - START
#####################
function getUserOU() {
<#
.DESCRIPTION
    This module is a helper module that helps us determine the Organizational unit of the incoming user object. This information is used to for example
    get the description of retrieved OU in other locations of the program. The OU Description contains external_id for an Organization on Zendesk.
    This external_id is used to then retrieve the Zendesk organization the user belongs to and the user can be created under that org.
.PARAMETER adUser
    The AD user object. 
.EXAMPLE
    $userOu = getUserOU -adUser $user -srcAD $srcAD;
.NOTES
#>
    
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="We determine the most relevant OU based on the incoming user.")]
        [ValidateNotNullOrEmpty()]
        $adUser,
        [Parameter(Mandatory=$true, HelpMessage="The source AD that the incoming AD user object is coming from.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('','')]
        $srcAD
    )
##
# Script execution from here on out
##
    if($srcAD -eq '') {
        $groupDistinguishedName = $adUser.PrimaryGroup; # Multi-level OU's can be the case on ... Therefore we want the most relevant OU. The thought is that prim. group location is the closest.        
    } elseif($srcAD -eq '') {
        $groupDistinguishedName = $adUser.memberOf | Select-Object -First 1; # Only 1-level OU's on ... So we are already close to source of the OU that has the description we want.
    }
    
    # Only continue if the $group variable got populated
    if($groupDistinguishedName)
    {
        $groupDistinguishedNameSplitted = $groupDistinguishedName -split ","; # , is the seperator between sub-parts of the DistinguishedName AD group property
    
        # Set variable to be used in the Join string method
        $Seperator = ",";
        $start = 1; # We know that we never want the second entry in the array (0 idx). As this is the CN=groupName itself.
        $count = $groupDistinguishedNameSplitted.Length-1; # Want to join the rest of the string. So length -1 to account for the fact that we are filtering out the first entry in the array
    
        # Join the string 
        $GroupOuDistinguishedName = [string]::Join($seperator,$groupDistinguishedNameSplitted,$start,$count);
        
        # Debug log the value of $GroupOuDistinguishedName
        $log4netLoggerDebug.debug("getUserOU() | Value to be used on Get-ADOrganizationalUnit's -Id parm.: $GroupOuDistinguishedName.");
        
        # Retrieve the OU wherein the users primary group is located
        try {
            $userOU = Get-ADOrganizationalUnit -Identity $GroupOuDistinguishedName -Properties Description -ErrorAction Stop;
        } catch {
            throw "Could not get an OU. Get-ADOrganizationalUnit failed with: $_"
        }
        
        return $userOU; 
    } else {
        # Log it with log4net
        $log4netLogger.error("getUserOU() | No group DistinguishedName could be determined from incoming adUser.");
        throw "getUserOU() | No group DistinguishedName could be determined from incoming adUser."
    }
} # End of function declaration

Export-ModuleMember -Function getUserOU;
###################
# FUNCTION - END
###################