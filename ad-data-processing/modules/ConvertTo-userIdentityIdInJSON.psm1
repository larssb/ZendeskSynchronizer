#####################
# FUNCTION - START
#####################
function ConvertTo-userIdentityIdInJSON() {
<#
.DESCRIPTION
    - Prepares a users Zendesk identity ID data so that it is in JSON. Ready for sending to the makeZendeskUserIdentityPrimary
    ExpressJS endpoint.
.PARAMETER identityID
    The ID of the identity on the Zendesk user.     
.PARAMETER zendeskUserId
    The users id number on Zendesk.    
.EXAMPLE
    $identityIDinJSON = ConvertTo-userIdentityIdInJSON -identityID $identityID -zendeskUserId $zendeskUserId;
.NOTES
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="The ID of the identity on the Zendesk user.")]
        [ValidateNotNullOrEmpty()]
        $identityID,
        [Parameter(Mandatory=$true, HelpMessage="The users id number on Zendesk.")]
        [ValidateNotNullOrEmpty()]
        $zendeskUserId                         
    )
####
# Script execution from here on out
####
    # Create hash to hold the data for correct JSON structure.
    $JSONouterContainer = @{};

    # Finalize JSON structure construction
    $JSONouterContainer.usersIdOnZendesk = $zendeskUserId;
    $JSONouterContainer.usersIdentityIdOnZendesk = $identityID;

    # Convert values to JSON    
    $identityIdInJSON = ConvertTo-Json -InputObject $JSONouterContainer;

    # Return
    $identityIdInJSON;
}

Export-ModuleMember -Function ConvertTo-userIdentityIdInJSON;
###################
# FUNCTION - END
###################