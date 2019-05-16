################
# Script preparation
################
# Load PSSnapins, modules x functions
Import-Module $PSScriptRoot\zendeskIntegrationConfig.psm1 -force # Module that configures settings such as vars which is used throughout.

#####################
# FUNCTION - START
#####################
function test-emailValidity() {
<#
.DESCRIPTION
    Checks if an AD Users e-mail is valid according to the following rules:
        -1- The e-mail address does not match a specific domain.
        -2- Unless the distinguishedname of the user match that same specific domain.

    If the e-mail address matches the domain and at the same time the distinguishedname does not
    match the domain the e-mail address shoul be removed from the adUser object coming in.

    Only relevant for .... Because the administration uses their own e-mail address
    when creating users on ... Zendesk will then error when we try to sync the e-mail address to
    Zendesk, as the e-mail address already exsists.

    We don't look to get users on ... synchronized to Zendesk. As we only want the users from ... AD. Therefore
    we don't do any data validation to include users from the ... AD.

    - The function returns a boolean $true or $false.
.PARAMETER adUser
    The ad user object to control e-mail address on.
.EXAMPLE
    $emailValid = test-emailValidity -adUser $adUser OR $emailValid = test-emailValidity -adUser $adUser.value (if the user is inside as hashtable).
.NOTES
#>
	# Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="The ad user object to control e-mail address on.")]
        [ValidateNotNullOrEmpty()]
        $adUser
    )
##
# Script execution from here on out
##
    # Control the validity of the ad users e-mail property.
    if ($aduser.email -notmatch "@.....") {
        $emailValid = $true;
    } else {
        $emailValid = $false;
    }

    # Return the result
    $emailValid;
}

Export-ModuleMember -Function test-emailValidity;
###################
# FUNCTION - END
###################