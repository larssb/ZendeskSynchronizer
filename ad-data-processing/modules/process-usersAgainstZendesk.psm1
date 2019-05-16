################
# Script preparation
################

## ! Load PSSnapins, modules x functions
Import-Module -Name $PSScriptRoot\zendeskIntegrationConfig.psm1 -force # Module that configures settings such as vars which is used throughout.
Import-Module -Name $PSScriptRoot\determineUserPrimaryPhone.psm1 -force
Import-Module -Name $PSScriptRoot\getUsersInOu.psm1 -force
Import-Module -Name $PSScriptRoot\transformUsersToJSON.psm1 -force
Import-Module -Name $PSScriptRoot\confirm-shouldUserBeIncluded.psm1 -force
Import-Module -Name $PSScriptRoot\userToJSON -Force # Helper module that transform an AD user object to JSON.
Import-Module -Name $PSScriptRoot\test-emailValidity -Force # Helper module that checks a ... users e-mail address to control whether it should be included on the user or not.
Import-Module -Name $PSScriptRoot\resolve-userEmailUpdated -force # Handles the case where a users primary e-mail address has been updated on AD.

#####################
# FUNCTION - START
#####################
function process-usersAgainstZendesk() {
<#
.DESCRIPTION
    Function that processes users against Zendesk to determine if they should be [updated] or [created]. Used for [full] sync     
.PARAMETER $ou
    A company AD organizational unit.
.PARAMETER $srcAD  
    Used to specify the source of the AD for which data is being processed.
.PARAMETER $companyZendeskOrgID
    The Zendesk org. id that the company was assigned by Zendesk.                  
.NOTES
#>
# DEFINE PARAMETERS
    param(
        [Parameter(Mandatory=$true, HelpMessage="A company AD organizational unit.")]
        [ValidateNotNullOrEmpty()]
        $ou,
        [Parameter(Mandatory=$true, HelpMessage="Used to specify the source of the AD for which data is being processed.")]
        [ValidateNotNullOrEmpty()]        
        $srcAD,
        [Parameter(Mandatory=$true, HelpMessage="The Zendesk org. id that the company was assigned by Zendesk.")]
        [ValidateNotNullOrEmpty()]        
        $companyZendeskOrgID        
    )
# PREPARE FUNCTION
    if( $null -eq (get-variable WebReqURI_updateZendeskUsers -ErrorAction SilentlyContinue) -or $null -eq (get-variable WebReqURI_listZendeskUsers -ErrorAction SilentlyContinue) ) {
        # Set Invoke-WebRequest as this is the first time we load the zendeskIntegrationConfig module
        set-listZendeskUsers_InvokeWebRequestVars; # Function in zendeskIntegrationConfig module, used to define listZendeskUsers web request vars
        set-updateZendeskUsers_InvokeWebRequestVars;
    }
# RUN     
    ####
    ## [Create] OR [Update] users on Zendesk in the OU sent to the function.  
    ####  
    # Get list of users in current company from Zendesk
    [Array]$companyZendeskOrgIdTempArray = $companyZendeskOrgID # Needed to get proper JSON
    $companyZendeskOrgIdInJSON = convertto-json -inputObject $companyZendeskOrgIdTempArray;
    try {
        $WebReqlistZendeskUsersOutput = Invoke-WebRequest -Uri $WebReqURI_listZendeskUsers -Method $WebReqMethod_POST -Body $companyZendeskOrgIdInJSON -ContentType $WebReqContent -ErrorVariable listZendeskUsersReqError;
    } catch {
        # Log it with log4net                    
        $log4netLogger.error("a) process-usersAgainstZendesk() | Invoke Web request failed on: WebReqURI_listZendeskUsers, with: $_");
        $log4netLogger.error("b) process-usersAgainstZendesk() | listZendeskUsers call Ps error variable: $listZendeskUsersReqError.");
    }
    
    # If request succeeded distinquise between users to be [created] & users to be [updated]
    if(!$listZendeskUsersReqError -and $null -ne $WebReqlistZendeskUsersOutput) {
        # No error occurred trying to get a list of Zendesk users underneath the Zendesk org. Check if HTTP200 OK was the response.        
        if($WebReqlistZendeskUsersOutput.StatusCode -eq 200) {
            # Get users in the OU currently being processed
            [array]$users = getUsersInOu -ou $ou -srcAD $srcAD;
            
            # First check if $users contains any users at all. If not there is no reason to do anything (there was no users in the OU).
            if($users.length -ge 1) {
                # Create collections to hold users to be [created] or [updated] on Zendesk.
                $usersToBeCreated = @{};
                $usersToBeUpdated = @{};
                
                # Determine if users should be [updated] or [created] on Zendesk by comparing user in the list from Zendesk with users retrieved by querying AD above
                foreach($user in $users) {
                    # Confirm if user should be included as either a user to be [updated] or [created]
                    [boolean]$userOk = confirm-shouldUserBeIncluded -srcAD $srcAD -adUser $user;
    
                    # Check if the user is ok and therefore should be sent to Zendesk
                    if($userOk -eq $true) {   
                        if($WebReqlistZendeskUsersOutput.content.contains($user.external_id)) {
                            $zendeskUserCollectionIdx = $users.external_id.IndexOf($user.external_id);
                            $zendeskUserToUpdate = $users.get($zendeskUserCollectionIdx);
                            $usersToBeUpdated.add($zendeskUserToUpdate.external_id, $zendeskUserToUpdate);
                        } else {
                            $usersToBeCreated.add($user.external_id, $user); # User GUID OR SID is the hashtable key (depending on the source AD).
                        }
                    }
                }
    
                # Get the first user. We just need the DistinguishedName AD attribute & this is the same for all users located in the OU currently being processed
                try {            
                    $adUser = $users.get(0);
                } catch {
                    # Log it with log4net                    
                    $log4netLogger.error("process-usersAgainstZendesk() | The users array was malformed. No user could be retrieved from it.");                    
                } 
    
                # Get the primary phone number that should be set on each user.
                $userPrimaryPhone = determineUserPrimaryPhone -adUser $adUser -fullSync -srcAD $srcAD -compOU $ou;
                
                # Only create users if there is actually any users in the $usersToBeCreated hashtable
                if($usersToBeCreated.count -ge 1) {
                    #### [CREATE] USERS ####
                    # Check if number of users is above 100. If so we will have to give Zendeks max 100, therefore split into smaller collections.
                    # See: https://developer.zendesk.com/rest_api/docs/core/users#create-many-users (Accepts an array of up to 100 user objects)
                    if($usersToBeCreated.count -gt 100) {
                        $usersToBeCreatedEnumerator = $usersToBeCreated.GetEnumerator();
                        $tempHash = @{};
                        while($usersToBeCreatedEnumerator.MoveNext()) {
                            if($tempHash.Count -gt 0) {
                                $tempHash = @{};
                            }
                        
                            # add 100 users to the tempHash collection - to match Zendesk 'create many users - endpoint' REST API  requirements
                            for($i = 1; $i -le 99; $i++) {
                                $currentElement = $usersToBeCreatedEnumerator.Current;
                                if($currentElement) {
                                    $tempHash.add($currentElement.key, $currentElement.value)
                                } else {
                                    break
                                }
                                $usersToBeCreatedEnumerator.MoveNext() | Out-Null;
                            }
                        
                            # Get the last element of the loop.
                            $currentElement = $usersToBeCreatedEnumerator.Current;
                            if($currentElement) {
                                $tempHash.add($currentElement.key, $currentElement.value)
                            }
                            
                            # Transform users to be created to JSON
                            $usersToBeCreatedonZendeskInJSON = transformUsersToJSON -userHASHCollToTransform $tempHash -zendeskAssignedOrgID $companyZendeskOrgID -userPrimaryPhone $userPrimaryPhone -transformType 'full' -srcAD $srcAD;
                            
                            if ($null -ne $usersToBeCreatedonZendeskInJSON) {
                                # Send the JSON user data to the createZendeskUsers endpoint. This is a private function in this module.
                                createZendeskUsersEndpoint $usersToBeCreatedonZendeskInJSON;                            
                            }
                        }
                    } else {
                        # Transform users to be created to JSON
                        $usersToBeCreatedonZendeskInJSON = transformUsersToJSON -userHASHCollToTransform $usersToBeCreated -zendeskAssignedOrgID $companyZendeskOrgID -userPrimaryPhone $userPrimaryPhone -transformType 'full' -srcAD $srcAD;
  
                        if ($null -ne $usersToBeCreatedonZendeskInJSON) {
                            # Send the JSON user data to the createZendeskUsers endpoint. This is a private function in this module.
                            createZendeskUsersEndpoint $usersToBeCreatedonZendeskInJSON;
                        }
                    }
                } # End of condition check on $usersToBeCreated.count
                
                if($usersToBeUpdated.count -ge 1) {             
                    #### [UPDATE] USERS ####
                    # Iterate over the [UPDATE] users collection --> to get the user AD object transformed into JSON
                    $tempUsers = @{};
                    $tempUsers.users = @();
                    $usersToBeUpdatedEnumerator = $usersToBeUpdated.GetEnumerator();                                                
                    
                    foreach($user in $usersToBeUpdatedEnumerator) 
                    {
                        # Call test-emailValidity() to control if the users e-mail address property should be included or not. Only relevant for ...
                        if ($srcAD -eq '') {
                            $emailValid = test-emailValidity -adUser $user.value;
                        }    

                        if ($emailValid -eq $true -or $srcAd -eq '') {
                            # Log that we are looking at the users e-mail
                            $log4netLoggerDebug.debug("process-usersAgainstZendesk() | Comparing & handling the users - $($user.value.external_id) - e-mail address to see if it should be a new primary identity on Zendesk.");

                            # Resolve the e-mail update case with a call to the resolve-userEmailUpdated module.
                            $userPropertyAdjusted = resolve-userEmailUpdated -user $user.value;                             
                        } else {
                            # Clean properties on the user we don't want send to Zendesk
                            $userPropertyAdjusted = $user.value | Select-object name,mobile,external_id;
                        }                        
                        
                        # Get the user transformed to JSON 
                        $userInJSON = userToJSON -transformType 'update' -adUser $userPropertyAdjusted;

                        # Add the user to the $users hashtable
                        $tempUsers.users += $userInJSON;            
                    }
                    
                    # Check if there is actually any users in the JSON object. Before blindly returning the JSON object to the main script. 
                    if($tempUsers.users.Count -ge 1) {
                        # Convert the users object to JSON & return it
                        $usersToBeUpdatedonZendeskInJSON = ConvertTo-Json -InputObject $tempUsers -Depth 3;
                    } else {
                        # Log it with log4net
                        $log4netLogger.error("a) process-usersAgainstZendesk() | FULL SYNC | No users was transformed to JSON. Critical failure!");        
                        $log4netLogger.error("b) process-usersAgainstZendesk() | FULL SYNC | Users variable contains: $tempUsers");
                        
                        # Throw error to caller
                        throw "process-usersAgainstZendesk() | No users was transformed to JSON. Critical failure!";
                    }                           
                    
                    # Define updateZendeskUsers web request vars & ask Zendesk to update the users                            
                    if( $null -eq (get-variable WebReqURI_updateZendeskUsers -ErrorAction SilentlyContinue) ) {
                        set-updateZendeskUsers_InvokeWebRequestVars; # Function in the zendeskIntegrationConfig module
                    }
                    
                    try {
                        Invoke-WebRequest -Uri $WebReqURI_updateZendeskUsers -Method $WebReqMethod_POST -Body ([System.Text.Encoding]::UTF8.GetBytes($usersToBeUpdatedonZendeskInJSON)) -ContentType $WebReqContentUsers -ErrorVariable updateZendeskUsersReqError;
                    } catch {
                        # Log it with log4net                    
                        $log4netLogger.error("a) process-usersAgainstZendesk() | Invoke Web request failed on: WebReqURI_updateZendeskUsers, with: $_");
                        $log4netLogger.error("b) process-usersAgainstZendesk() | updateZendeskUsers call Ps error variable: $updateZendeskUsersReqError.");
                            
                        # Clean-up
                        remove-variable -Name updateZendeskUsersReqError;
                    }
                } # End of condition check on $usersToBeUpdated.count
            } else {
                # Log it with log4net      
                if($ou.Gettype().Name -eq 'DictionaryEntry') {
                    $ouInfo = $ou.value;
                } else {
                    $ouInfo = $ou;
                }               
                $log4netLogger.error("process-usersAgainstZendesk() | No users was retrieved with getUsersinOu. Was working with OU: $ouInfo.");
            } # End of condition check on $users.length. If 0 now users was retrieved in the OU. No reason to do anything then.
        } else {
            # Log it with log4net                    
            $log4netLogger.error("a) process-usersAgainstZendesk() | The status code on WebReqlistZendeskUsersOutput was different from HTTP200. Unknown state, cannot continue.");
            $log4netLogger.error("b) process-usersAgainstZendesk() | The status code returned is: $($WebReqUpdateZendeskOrgOutput.StatusCode).");
            throw "process-usersAgainstZendesk() | The statusCode on WebReqlistZendeskUsersOutput was different from 200OK. Unknown state, cannot continue."      
        } # End of condition check on $WebReqlistZendeskUsersOutput
    } else {
        # Log it with log4net                    
        $log4netLogger.error("process-usersAgainstZendesk() | Control on listZendeskUsersReqError & WebReqlistZendeskUsersOutput variables failed. The invoke-webrequest cmdlet likely failed. Analyze the log.");
    } # End of condition check on $listZendeskUsersReqError & WebReqlistZendeskUsersOutput
} # End of process-usersAgainstZendesk function declaration

############################
# PRIVATE HELPER FUNCTIONS #
############################
# Function that request the ExpressJS endpoint createZendeskUsers to create users on Zendesk
function createZendeskUsersEndpoint($usersToBeCreatedonZendeskInJSON) {
    # Define createZendeskUsers web request vars & ask Zendesk to create the users
    if( $null -eq (get-variable WebReqURI_createZendeskUsers -ErrorAction SilentlyContinue) ) {    
        set-createZendeskUsers_InvokeWebRequestVars; # Function in the zendeskIntegrationConfig module, used to define createZendeskUsers web request vars
    }
    
    try {
        Invoke-WebRequest -Uri $WebReqURI_createZendeskUsers -Method $WebReqMethod_POST -Body ([System.Text.Encoding]::UTF8.GetBytes($usersToBeCreatedonZendeskInJSON)) -ContentType $WebReqContentUsers -ErrorVariable createZendeskUsersReqError;
    } catch {
        # Log it with log4net                    
        $log4netLogger.error("a) process-usersAgainstZendesk() | Invoke Web request failed on: WebReqURI_createZendeskUsers, with: $_");
        $log4netLogger.error("b) process-usersAgainstZendesk() | createZendeskUsers call Ps error variable: $createZendeskUsersReqError.");
 
        write-output "inside process-usersAgainstZendesk(). Catch error on [create] zendesk users invoke-webrequest call. Failed with: " $_;
        
        # Clean-up
        remove-variable -Name createZendeskUsersReqError;
    }
}

Export-ModuleMember -Function process-usersAgainstZendesk;
###################
# FUNCTION - END
###################