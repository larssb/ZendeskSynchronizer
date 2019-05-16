#####################
# FUNCTION - START
#####################
function transformUserUniqueIdToJSON() {
<#
.DESCRIPTION
    This helper function transforms a customer user unique ID (ObjectGUID on ... and SID on ...) to JSON which can then be sent to Zendesk in various situations.
.PARAMETER user
    The user parameter is used to provide a customer user object. This object contains the ObjectGUID or SID renamed to external_ID.
.EXAMPLE
    $userUniqueIdInJSON = transformUserUniqueIdToJSON -user $user;
.NOTES
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="Company user which contains ObjectGUID or SID (external_ID) to be formalized into JSON.")]
        [ValidateNotNullOrEmpty()]
        $user
    )
####
# Script execution from here on out
####
    # HASHtable that is to contain the users unique ID in JSON format
    $userUniqueID = @{};
    
    $userUniqueID.external_id = $user.external_id;

    # Convert the debitornumber to JSON
    $userUniqueIDInJSON = ConvertTo-Json -InputObject $userUniqueID;

    # Log it with log4net
    $log4netLoggerDebug.debug("transformUserUniqueIdToJSON() | Content of userUniqueID: $userUniqueIDInJSON");

    # Return
    $userUniqueIDInJSON;
} # End of function declaration

Export-ModuleMember -Function transformUserUniqueIdToJSON;
###################
# FUNCTION - END
###################