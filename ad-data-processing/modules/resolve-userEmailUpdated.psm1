####################
# FUNCTIONS - PREP
####################
Import-Module -name $PSScriptRoot\ConvertTo-userIdentityInJSON -force; # Prepares an AD users identity related data to be sent to Zendesk. Takes a type parameter used to define which type of identity it is.
Import-Module -name $PSScriptRoot\invoke-createZendeskUserIdentityEndpoint -force; # Loads the createZendeskUserIdentityEndpoint module. In order to get an identity created under a specific Zendesk user.
Import-Module -name $PSScriptRoot\invoke-makeZendeskUserIdentityPrimaryEndpoint -force; # Loads the invoke-makeZendeskUserIdentityPrimaryEndpoint module. In order to make an users Zendesk identity the primary identity.
Import-Module -name $PSScriptRoot\ConvertTo-userIdentityIdInJSON -force; # Prepares a Zendesk users identity ID to JSON.
Import-Module -Name $PSScriptRoot\invoke-getZendeskUserEndpoint -force # Loads the invoke-getZendeskUserEndpoint module. Used to get a user on Zendesk.
Import-Module -name $PSScriptRoot\transformUserUniqueIdToJSON -force # Module that transforms a users unique ID into JSON

####################
# FUNCTIONS - START
####################
function resolve-userEmailUpdated() {
<#
.DESCRIPTION
    Handles the case where a users primary e-mail address has been updated on AD. Then the e-mail is to be compared
    to the e-mail data on the user on Zendesk. If they don't match a new e-mail identity is created on Zendesk. Then this
    new e-mail identity is set to be the primary.

    - Returns
    on success and failure == a user object modified to contain only relevant properties based on the outcome of comparing e-mail data to Zendesk and
    so forth.
.PARAMETER user

.EXAMPLE
    $userPropertyAdjusted = resolve-userEmailUpdated -user $user;
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="An AD user object.")]
        [ValidateNotNullOrEmpty()]
        $user
    )
####
# Script execution from here on out
####
    try {
        # Get the users external_ID (ObjectGUID or SID) in JSON.
        $userUniqueIDInJSON = transformUserUniqueIdToJSON -user $user;
    } catch {
        # error log
        $log4netLogger.error("resolve-userEmailUpdated() - UPDATE - | transformUserUniqueIdToJSON() failed with: $_");            
    }

    if ($null -ne $userUniqueIDInJSON) {
        # Try to get the user from Zendesk
        try {
            $WebReqGetUserOutput = invoke-getZendeskUserEndpoint -userUniqueIDInJSON $userUniqueIDInJSON;
        } catch {
            "- Failed to get the user from Zendesk. This error has already been logged in the get-zendeskUser private function.";
        }

        if($WebReqGetUserOutput.StatusCode -eq 200) 
        {
            # Compare e-mail data
            $userFromZendesk = ConvertFrom-Json -InputObject $WebReqGetUserOutput.content;
            $userFromZendeskEmail = $userFromZendesk.email;
            $userFromAdEmail = $user.email;

            # Control if it is different from the users e-mail address on Zendesk.
            if ($userFromAdEmail -notmatch $userFromZendeskEmail) 
            {
                # Create an e-mail identity on the Zendesk user
                $userFromZendesk_ID = $userFromZendesk.id;
                $identityInJSON = ConvertTo-userIdentityInJSON -identityType email -identityValue $userFromAdEmail -zendeskUserId $userFromZendesk_ID;
                $identityCreationWebReqOutput = invoke-createZendeskUserIdentityEndpoint -identityInJSON $identityInJSON;

                if ($identityCreationWebReqOutput.StatusCode -eq 201) 
                {
                    # Prepare & get data for making the newly created identity the primary identity on the Zendesk user 
                    $identityFromZendesk = ConvertFrom-Json -InputObject $identityCreationWebReqOutput.content;
                    $identityFromZendesk_ID = $identityFromZendesk.id;
                    $identityIdInJSON = ConvertTo-userIdentityIdInJSON -identityID $identityFromZendesk_ID -zendeskUserId $userFromZendesk_ID;

                    # Make the identity we just added the primary identity on the Zendesk user
                    $makeIdentityPrimaryWebReqOutput = invoke-makeZendeskUserIdentityPrimaryEndpoint -identityIdInJSON $identityIdInJSON;

                    if ($makeIdentityPrimaryWebReqOutput.StatusCode -eq 200) {
                        # Log success
                        $log4netLoggerDebug.debug("resolve-userEmailUpdated() | Successfully created an identity on the user with Zendesk ID: $userFromZendesk_ID and made the identity the primary one.");
                    } else {
                        # error log
                        $log4netLogger.error("resolve-userEmailUpdated() - UPDATE - | The e-mail identity was not successfully set as the primary one.");            
                    }

                    # Clean properties on the user we don't want send to Zendesk
                    $userPropertyAdjusted = $user | Select-object name,mobile,external_id;
                } else {
                    # error log
                    $log4netLogger.error("resolve-userEmailUpdated() - UPDATE - | A new e-mail identity was not successfully created on the user. The e-mail property will be stripped from the user.");            

                    # Remove the e-mail property from the users properties to avoid the e-mail data to be synchronized to Zendesk
                    $userPropertyAdjusted = $user | Select-object name,mobile,external_id;
                }
            } else {
                # Log debug data
                $log4netLoggerDebug.debug("a) resolve-userEmailUpdated() | The e-mail on AD and Zendesk was found to match.");
                $log4netLoggerDebug.debug("b) resolve-userEmailUpdated() | The e-mails compared: $userFromAdEmail (AD data) <-> $userFromZendeskEmail (Zendesk).");

                # Clean properties on the user we don't want send to Zendesk. The e-mail addresses are the same, no reason to send the e-mail address property.
                $userPropertyAdjusted = $user | Select-object name,mobile,external_id;
            }
        } else {
            <# 
                - Strip the email property from the user. If we don't we risk the user getting a verification e-mail from Zendesk & an extra 
                e-mail on the user, which we might not want.
            #>
            $userPropertyAdjusted = $user | Select-object name,mobile,external_id;
        }

        # Return
        $userPropertyAdjusted;
    } else {
        <# 
            - Strip the email property from the user. If we don't we risk the user getting a verification e-mail from Zendesk & an extra 
            e-mail on the user, which we might not want.
        #>
        $userPropertyAdjusted = $user | Select-object name,mobile,external_id;

        # Return
        $userPropertyAdjusted;
    }
}

Export-ModuleMember -Function resolve-userEmailUpdated;
###################
# FUNCTIONS - END
###################