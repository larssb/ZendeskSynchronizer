################
# Script preparation
################

## ! Load PSSnapins, modules x functions
Import-Module -Name $PSScriptRoot\purifyOuDescription.psm1 -force # Module that returns the debitor num or GUID part of the OU description.

#####################
# FUNCTION - START
#####################
function transformOuDescriptionToJSON() {
<#
.DESCRIPTION
    This helper function transforms a customers internal ID (debitor number ... | GUID OR customized debitor number on ...) to JSON which can then be sent to Zendesk in various situations.
.PARAMETER ou
    The OU parameter is used to provide a customer organizational unit object. This object contains debitornumber (in the OU description)
.EXAMPLE
    transformOuDescriptionToJSON -ou $ou;
.NOTES
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="The AD organizational unit object which descriptions is to be transformed into JSON.")]
        [ValidateNotNullOrEmpty()]
        $ou
    )
##
# Script execution from here on out
##
    # HASHtable to contain the debitornumber in JSON format
    $ouDescription = @{};

    # As the incoming ou can both come from a loop over a HASHtable, an Array & regular AD OU object we have to determine which one it is
    if($null -ne $ou.Value.external_id) {
        # Debug log
        $log4netLoggerDebug.debug("transformOuDescriptionToJSON() - Value.external_id - | Value of OU description: $($ou.Value.external_id).");
        
        # Check OU external_Id (description) data & manipulate it to only get debitorNumber or GUID
        $purifiedOuDescription = purifyOuDescription -ouDescription $ou.Value.external_id;
        $ouDescription.external_id = $purifiedOuDescription;
    } elseif( ($ou | gm).Name.ToLower().contains("external_id".ToLower()) ) {
        # Debug log
        $log4netLoggerDebug.debug("transformOuDescriptionToJSON() - external_id - | Value of OU description: $($ou.external_id).");

        # Check OU external_Id (description) data & manipulate it to only get debitorNumber or GUID
        $purifiedOuDescription = purifyOuDescription -ouDescription $ou.external_id;
        $ouDescription.external_id = $purifiedOuDescription;
    } elseif( ($ou | gm).Name.ToLower().contains("description".ToLower()) ) {
        # Debug log
        $log4netLoggerDebug.debug("transformOuDescriptionToJSON() - description - | Value of OU description: $($ou.description).");
        
        # OU Description property has not been renamed to external_id --> act accordingly
        # Check OU external_Id (description) data & manipulate it to only get debitorNumber or GUID
        $purifiedOuDescription = purifyOuDescription -ouDescription $ou.description;
        $ouDescription.external_id = $purifiedOuDescription;
    } else {
        # Log it with log4net
        $log4netLogger.error("a) transformOuDescriptionToJSON() | OU description could not be determined.");
        $log4netLogger.error("b) transformOuDescriptionToJSON() | OU data: $ou");
    }
    
    # Convert the debitornumber to JSON
    $ouDescriptionInJSON = ConvertTo-Json -InputObject $ouDescription;

    # Return the result
    return $ouDescriptionInJSON;
}

Export-ModuleMember -Function transformOuDescriptionToJSON;
###################
# FUNCTION - END
###################