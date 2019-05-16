################
# Script preparation
################

## ! Load PSSnapins, modules x functions
Import-Module $PSScriptRoot\zendeskIntegrationConfig.psm1 -force # Module that configures settings such as vars which is used throughout.

#####################
# FUNCTION - START
#####################
function purifyOuDescription() {
<#
.DESCRIPTION
    Helper function checking the incoming description of an OU, to purify it, if neccessary, so that the returned description data only consists of
	debitor number or GUID.
.PARAMETER ouDescription
    The description of the OU.
.EXAMPLE
    purifyOuDescription -ouDescription $ouDescription
.NOTES
#>
    
	# Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="The description of the OU.")]
        [ValidateNotNullOrEmpty()]
        $ouDescription
    )
##
# Script execution from here on out
##
    # Set reg. expression vars -- Before trying to set it, check if it haven't already been set.
    if( $null -eq (get-variable C5OClassicOuDescriptionRegEx -ErrorAction SilentlyContinue) ) {
        set-regularExpressionVars; # Function in zendesk config module.
    }
    
    # Check if OU description matches C5OClassic OU description. If so purify it.
    if($ouDescription -match $C5OClassicOuDescriptionRegEx) {
        $purifiedOuDescription = (Select-String -pattern "\d+" -InputObject $ouDescription).matches.value;
    } else {
        # OU description did not have to be purified it is fine as is.
        $purifiedOuDescription = $ouDescription;
    }
    
    # Return the purified OU description to caller
    return $purifiedOuDescription;
}

Export-ModuleMember -Function purifyOuDescription;
###################
# FUNCTION - END
###################