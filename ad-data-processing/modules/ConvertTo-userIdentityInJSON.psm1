#####################
# FUNCTION - START
#####################
function ConvertTo-userIdentityInJSON() {
<#
.DESCRIPTION
    - Prepares an AD users identity related data to be sent to Zendesk. Takes a type parameter used to define which type of
    identity it is.
.PARAMETER identityType
    The type of Zendensk identity. 
.PARAMETER identityData
    The data of the Zendensk identity.     
.PARAMETER zendeskUserId
    The users id number on Zendesk.    
.EXAMPLE
    
.NOTES
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="The type of Zendensk identity.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('email','twitter','facebook','google')]       
        $identityType,
        [Parameter(Mandatory=$true, HelpMessage="The data of the Zendensk identity.")]
        [ValidateNotNullOrEmpty()]
        $identityValue,
        [Parameter(Mandatory=$true, HelpMessage="The users id number on Zendesk.")]
        [ValidateNotNullOrEmpty()]
        $zendeskUserId                         
    )
####
# Script execution from here on out
####
    # Create hash to hold the data for correct JSON structure.
    $JSONouterContainer = @{};
    $identityData = @{};

    # Set values
    $identityData.type = $identityType;
    $identityData.value = $identityValue;
    $identityData.verified = $true; # As we want to avoid having a verification e-mail sent out by the Zendesk system.

    # Finalize JSON structure construction
    $JSONouterContainer.identityDataToZendesk = $identityData;
    $JSONouterContainer.usersIdOnZendesk = $zendeskUserId;

    # Convert values to JSON    
    $identityInJSON = ConvertTo-Json -InputObject $JSONouterContainer;

    # Return
    $identityInJSON;
}

Export-ModuleMember -Function ConvertTo-userIdentityInJSON;
###################
# FUNCTION - END
###################