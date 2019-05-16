################
# Script preparation
################

## ! Load PSSnapins, modules x functions
Import-Module -name $PSScriptRoot\zendeskIntegrationConfig -force # Module that configures settings such as vars which is used throughout.
Import-Module -name $PSScriptRoot\transformUserUniqueIdToJSON -force # Module that transforms a users unique ID into JSON
Import-Module -name $PSScriptRoot\transformOuDescriptionToJSON -force # Module that transforms an OU's description to JSON
Import-Module -name $PSScriptRoot\determineUserModifiedStatus -force # Module that determines if a user has been updated on a source AD on AD attributes which makes us want to update the user on Zendesk
Import-Module -name $PSScriptRoot\determineUserPrimaryPhone -force # Module that determines a users primary phone number
Import-Module -name $PSScriptRoot\getUserOU -force # Helper module that can determine what OU a user belongs to. 
Import-Module -name $PSScriptRoot\confirm-shouldUserBeIncluded -force # Helper module that determines if an user should be included in the resulting $users collection
Import-Module -name $PSScriptRoot\userToJSON -Force # Helper module that transform an AD user object to JSON.
Import-Module -name $PSScriptRoot\3rdParty\ExecutionInfo -Force
Import-Module -name $PSScriptRoot\test-emailValidity -Force # Helper module that checks a ... users e-mail address to control whether it should be included on the user or not.
Import-Module -Name $PSScriptRoot\invoke-getZendeskUserEndpoint -force # Loads the invoke-getZendeskUserEndpoint module. Used to get a user on Zendesk.
Import-Module -Name $PSScriptRoot\resolve-userEmailUpdated -force # Handles the case where a users primary e-mail address has been updated on AD.

#####################
# FUNCTION - START
#####################
function transformUsersToJSON() {
<#
.DESCRIPTION
    This module is called with certain parameters to reflect the sync mode and then queries a specific source AD for users matching the sync state. The retrieved users are then transformed
    into JSON and returned to the caller.
.PARAMETER ou
    OU AD object. Used in full sync mode to gathers users from. 
.PARAMETER zendeskAssignedOrgID
    The Zendesk ID of the organization a user is to be affiliated with. Used in 'create' & 'full' sync modes.
.PARAMETER transformType
    The type of sync the JSON output should match.
.PARAMETER srcAD
    The source AD of the  incoming AD objects.
.PARAMETER lastSync_dateTime
    Used for incremental sync modes. 'Create' & 'Update'. Part of the filter when querying AD for users.
.EXAMPLE
.NOTES
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, ParameterSetName="fullSync", HelpMessage="The Zendesk organization ID retrieved from Zendesk when the company was created.")]
        [ValidateNotNullOrEmpty()]
        $zendeskAssignedOrgID,
        [Parameter(Mandatory=$true, ParameterSetName="fullSync", HelpMessage="When transformtype is 'create' or 'full'. State the primary phone number of the user.")]
        [AllowNull()]
        [AllowEmptyString()]        
        $userPrimaryPhone,
        [Parameter(Mandatory=$true, ParameterSetName="fullSync", HelpMessage="The collection of AD users that should be transformed to JSON.")]
        [parameter(Mandatory=$true, ParameterSetName="createSync", HelpMessage="The collection of AD users that should be transformed to JSON.")]
        [parameter(Mandatory=$true, ParameterSetName="updateSync", HelpMessage="The collection of AD users that should be transformed to JSON.")]
        [ValidateNotNullOrEmpty()]          
        $userHASHCollToTransform,        
        [Parameter(Mandatory=$true, HelpMessage="Transform type is to tell the module if JSON is for incremental or full Zendesk users sync.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('create','update','full')]
        $transformType,
        [Parameter(Mandatory=$true, HelpMessage="Specify which AD is the src")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('','')]
        $srcAD,
        [Parameter(Mandatory=$true, ParameterSetName="updateSync", HelpMessage="Date and time of last incremental sync.")]
        [ValidateNotNullOrEmpty()]
        [DateTime]$lastSync_dateTime
    )
##
# Script execution from here on out
##
    <# 
        Create hashtable to be able to define the JSON object the Zendesk REST API expects when requesting it to create many users.
        These can be shared between the different transform types.
    #>
    $users = @{};
    $users.users = @();

    if($transformType -eq 'full') {
# FULL SYNC USERS TO JSON MODE     
        # Iterate over the 'create' collection --> to get the user AD object transformed into JSON
        $usersToBeCreatedEnumerator = $userHASHCollToTransform.GetEnumerator();
        foreach($user in $usersToBeCreatedEnumerator) {
            # Debug log
            $log4netLoggerDebug.debug("transformUsersToJSON() - FULL - | Working on user: $user.");

            # Call test-emailValidity() to control if the users e-mail address property should be included or not. Only relevant for ...
            if ($srcAD -eq '') {
                $emailValid = test-emailValidity -adUser $user.value;
            }    

            if ($emailValid -eq $true -or $srcAd -eq '') {
                # Clean properties on the user we don't want send to Zendesk
                $userPropertyAdjusted = $user.value | Select-object name,email,mobile,external_id;
            } else {
                # Clean properties on the user we don't want send to Zendesk
                $userPropertyAdjusted = $user.value | Select-object name,mobile,external_id;
            }

            # Get the user transformed to JSON 
            $userInJSON = userToJSON -transformType $transformType -adUser $userPropertyAdjusted -zendeskAssignedOrgID $zendeskAssignedOrgID -userPrimaryPhone $userPrimaryPhone;
            
            # Add the user to the $users hashtable
            $users.users += $userInJSON;            
        }  
    } elseif($transformType -eq 'create') {
# Incremental - 'Created users' to JSON mode   
        # Iterate over the 'create' collection --> to get the user AD object transformed into JSON
        try {
            $usersToBeCreatedEnumerator = $userHASHCollToTransform.GetEnumerator();
        } catch {
            # error log
            $log4netLogger.error("transformUsersToJSON() - CREATE - | Getting enumerator failed with: $_");            
        }
        
        # Get Users [CREATED] since last incremental sync
        foreach($user in $usersToBeCreatedEnumerator) {
            # Debug log
            $log4netLoggerDebug.debug("transformUsersToJSON() - CREATE - | Working on user: $($user.value.Name).");            
            
            # Check if the user should be included in the collection users to be created on Zendesk
            [boolean]$userOk = confirm-shouldUserBeIncluded -srcAD $srcAD -adUser $user.value;
            
            # User is ok and should be [created] on Zendesk --> call private function to get the user transformed to JSON & added to the $users coll.
            if($userOk -eq $true) {
                try {
                    $WebReqGetZendeskOrgOutput = getZendeskOrganization -user $user.value -srcAD $srcAD;
                    [string]$tempOrgId = (ConvertFrom-Json -InputObject $WebReqGetZendeskOrgOutput.Content).zendeskOrgId;
                    
                    # Determine users primary phone
                    try {
                        $tempUserPrimaryPhone = determineUserPrimaryPhone -adUser $user.value -srcAD $srcAD;
                        
                        # Log the primary phone number we got
                        $log4netLoggerDebug.debug("transformUsersToJSON() - Create - | determineUserPrimaryPhone(), we got phone num.: $tempUserPrimaryPhone.");
                    } catch {
                        # error log
                        $log4netLogger.error("transformUsersToJSON() - CREATE - | call to determineUserPrimaryPhone(). Failed with: $_");
                        
                        # ! We continue even though determining the users primary phone number failed above. Basically just failing gracefully. That is okay.
                        # We still want the user synchronized to Zendesk. We logged the error above.                                     
                    }

                    # Call test-emailValidity() to control if the users e-mail address property should be included or not. Only relevant for ...
                    if ($srcAD -eq '') {
                        $emailValid = test-emailValidity -adUser $user.value;
                    }

                    if ($emailValid -eq $true -or $srcAd -eq '') {
                        # Clean properties on the user we don't want send to Zendesk
                        $userPropertyAdjusted = $user.value | Select-object name,email,mobile,external_id;
                    } else {
                        # Clean properties on the user we don't want send to Zendesk
                        $userPropertyAdjusted = $user.value | Select-object name,mobile,external_id;
                    }
                    
                    # Get the user transformed to JSON 
                    $userInJSON = userToJSON -transformType $transformType -adUser $userPropertyAdjusted -zendeskAssignedOrgID $tempOrgId -userPrimaryPhone $tempUserPrimaryPhone;
                    
                    # Add the user to the $users hashtable
                    $users.users += $userInJSON;
                } catch {
                    # Log it with log4net
                    $log4netLogger.error("transformUsersToJSON() | getZendeskOrganization function failed with: $_");        
                }                
            }
        } # End of foreach on 'created' users AD query
    } else {
# Incremental - [UPDATE] user/s to JSON mode
        # Iterate over the 'update' collection --> to get the user AD object transformed into JSON
        try {
            $usersToUpdatedEnumerator = $userHASHCollToTransform.GetEnumerator();
        } catch {
            # error log
            $log4netLogger.error("transformUsersToJSON() - UPDATE - | Getting enumerator failed with: $_");            
        }
        
        # Get Users [MODIFIED] since last incremental sync. If any.
        foreach($user in $usersToUpdatedEnumerator) {
            # Debug log
            $log4netLoggerDebug.debug("transformUsersToJSON() - UPDATE - | Working on user: $($user.value.Name).");            
            
            # Check if the user should be included in the collection users to be created on Zendesk
            [boolean]$userOk = confirm-shouldUserBeIncluded -srcAD $srcAD -adUser $user.value;            

            # User is ok and should be further processed            
            if($userOk -eq $true) {
                try {
                    # Set variables with functions in the zendeskConfig module --> used to define the variable that defines the variable for the $srcDomain value.
                    if( $null -eq (get-variable ...AdDomain -ErrorAction SilentlyContinue) ) {             
                        set-AdDomainVars # This is an exported function in the zendeskIntegrationConfig module - Sets the domain name as we have multiple AD's in play
                    }

                    # Set the $srcDomain variable.
                    if($srcAD -eq '') 
                    { 
                        $srcDomain = $...AdDomain;
                    } elseif($srcAD -eq '') {
                        $srcDomain = $...AdDomain;            
                    }                    

                    # Determine if user has been modified/updated in a way which makes us interested in updating the user on Zendesk
                    [string]$userUpdatedStatus = determineUserModifiedStatus -user $user.value -lastSync_dateTime $lastSync_dateTime -srcDomain $srcDomain;
                } catch {
                    # error log
                    $log4netLogger.error("transformUsersToJSON() - UPDATE - | determineUserModifiedStatus() failed with: $_");            
                }
                
                # Check the result of determineUserModifiedStatus --> was the user really updated.
                if($userUpdatedStatus -eq 'Modified') {
                    # Call test-emailValidity() to control if the users e-mail address property should be included or not. Only relevant for ...
                    if ($srcAD -eq '') {
                        $emailValid = test-emailValidity -adUser $user.value;
                    }    

                    if ($emailValid -eq $true -or $srcAd -eq '') {
                        # Control if the users e-mail AD property was updated
                        [string]$userEmailUpdatedStatus = determineUserModifiedStatus -user $user.value -lastSync_dateTime $lastSync_dateTime -srcDomain $srcDomain -controlEmailOnly;                    
                        
                        if ($userEmailUpdatedStatus -eq 'Modified') {
                            # Log that we are looking at the users e-mail
                            $log4netLoggerDebug.debug("transformUsersToJSON() | Comparing & handling the users - $($user.value.external_id) - e-mail address to see if it should be a new primary identity on Zendesk.");

                            # Resolve the e-mail update case with a call to the resolve-userEmailUpdated module.
                            $userPropertyAdjusted = resolve-userEmailUpdated -user $user.value;
                        } else {
                            # Clean properties on the user we don't want send to Zendesk
                            $userPropertyAdjusted = $user.value | Select-object name,mobile,external_id;                            
                        }
                    } else {
                        # Clean properties on the user we don't want send to Zendesk
                        $userPropertyAdjusted = $user.value | Select-object name,mobile,external_id;
                    }                    
                    
                    # Get the user transformed to JSON 
                    $userInJSON = userToJSON -transformType $transformType -adUser $userPropertyAdjusted;
                    
                    # Add the user to the $users hashtable
                    $users.users += $userInJSON;
                } elseif($userUpdatedStatus -eq 'Activated') {
                    # Check if the user exists on Zendesk or not. In order to determine if the user should be updated or created on Zendesk.
                    try {
                        # Get the users external_ID (ObjectGUID or SID) in JSON.
                        $userUniqueIDInJSON = transformUserUniqueIdToJSON -user $user.value;
                    } catch {
                        # error log
                        $log4netLogger.error("transformUsersToJSON() - UPDATE - | transformUserUniqueIdToJSON() failed with: $_");            
                    }
         
                    try {
                       $WebReqGetUserOutput = invoke-getZendeskUserEndpoint -userUniqueIDInJSON $userUniqueIDInJSON;
                    } catch {
                        "- Failed to get the user from Zendesk. This error has already been logged in the get-zendeskUser private function.";
                    }

                    # Check if the user was retrieved successfully
                    if($WebReqGetUserOutput.StatusCode -eq 200) {
                        # Call test-emailValidity() to control if the users e-mail address property should be included or not. Only relevant for ...
                        if ($srcAD -eq '') {
                            $emailValid = test-emailValidity -adUser $user.value;
                        }    

                        if ($emailValid -eq $true -or $srcAd -eq '') {
                            # Log that we are looking at the users e-mail
                            $log4netLoggerDebug.debug("transformUsersToJSON() | Comparing & handling the users - $($user.value.external_id) - e-mail address to see if it should be a new primary identity on Zendesk.");

                            # Resolve the e-mail update case with a call to the resolve-userEmailUpdated module.
                            $userPropertyAdjusted = resolve-userEmailUpdated -user $user.value;                            
                        } else {
                            # Clean properties on the user we don't want send to Zendesk
                            $userPropertyAdjusted = $user.value | Select-object name,mobile,external_id;
                        }                         

                        # The user exists - The user should just be updated. First get the user transformed to JSON.
                        $userInJSON = userToJSON -transformType $transformType -adUser $userPropertyAdjusted;
                        
                        # Add the user to the $users hashtable
                        $users.users += $userInJSON;
                    } else {
                        # TODO - 160902: Could potentially end up in here even though the user exists on Zendesk.....
                        
                        <# 
                            - The user did not exist. Create the user on Zendesk --> first change transformType to 'create' with temp variable --> 
                            because user is not added to $users.users HASHtable and thereby not returned to caller. As we create it directly with
                            the below code.
                        #>
                        $tempTransformType = 'create';
                        
                        # Query private function to find Zendesk org. that the user should belong to.
                        $WebReqGetZendeskOrgOutput = getZendeskOrganization $user.value -srcAD $srcAD;
                        [string]$tempOrgId = (ConvertFrom-Json -InputObject $WebReqGetZendeskOrgOutput.Content).zendeskOrgId;
                            
                        # Determine users primary phone
                        try {
                            $tempUserPrimaryPhone = determineUserPrimaryPhone -adUser $user.value -srcAD $srcAD;
                            
                            # Log the primary phone number we got
                            $log4netLoggerDebug.debug("transformUsersToJSON() - Create - | determineUserPrimaryPhone(), we got phone num.: $tempUserPrimaryPhone.");
                        } catch {
                            # error log
                            $log4netLogger.error("transformUsersToJSON() - CREATE - | call to determineUserPrimaryPhone(). Failed with: $_");
                            
                            # ! We continue even though determining the users primary phone number failed above. Basically just failing gracefully. That is okay.
                            # We still want the user synchronized to Zendesk. We logged the error above.                                     
                        }

                        # Call test-emailValidity() to control if the users e-mail address property should be included or not. Only relevant for ...
                        if ($srcAD -eq '') {
                            $emailValid = test-emailValidity -adUser $user.value;
                        }    

                        if ($emailValid -eq $true -or $srcAd -eq '') {
                            # Clean properties on the user we don't want send to Zendesk
                            $userPropertyAdjusted = $user.value | Select-object name,email,mobile,external_id;
                        } else {
                            # Clean properties on the user we don't want send to Zendesk
                            $userPropertyAdjusted = $user.value | Select-object name,mobile,external_id;
                        }

                        # Get the user transformed to JSON 
                        $userInJSON = userToJSON -transformType $tempTransformType -adUser $userPropertyAdjusted -zendeskAssignedOrgID $tempOrgId -userPrimaryPhone $tempUserPrimaryPhone;
                        
                        # Define createZendeskUsers web request vars & ask Zendesk to create the user
                        if( $null -eq (get-variable WebReqURI_createZendeskUsers -ErrorAction SilentlyContinue) ) {                                
                            set-createZendeskUsers_InvokeWebRequestVars; # Function in zendeskIntegrationConfig module, used to define getZendeskOrganization web request vars
                        }

                        # Create hashtable to be able to define the JSON object the Zendesk REST API expects when requesting it to create the user.
                        $tempUsers = @{};
                        $tempUsers.users = @();

                        # Add the user to the  we transformed to JSON with the userToJSON function above
                        $tempUsers.users += $userInJSON;

                        # Convert the tempUsers collection, containing the current user to be created on Zendesk, to JSON.
                        $tempUsersInJSON = ConvertTo-Json -InputObject $tempUsers -Depth 3;

                        try {
                            # Create the user by invoking the createZendeskUsers ExpressJS endpoint.
                            $WebReqCreateZendeskUsers = Invoke-WebRequest -Uri $WebReqURI_createZendeskUsers -Method $WebReqMethod_POST -Body ([System.Text.Encoding]::UTF8.GetBytes($tempUsersInJSON)) -ContentType $WebReqContentUsers -ErrorVariable createZendeskUsersReqError;
                        } catch {
                            # Log it with log4net
                            $log4netLogger.error("a) transformUsersToJSON() | Sending users to createZendeskUsers ExpressJS endpoint failed with: $_");
                            $log4netLogger.error("b) transformUsersToJSON() | createZendeskUsers call Ps error variable: $createZendeskUsersReqError");
                            
                            # Clean-up
                            if( $null -ne (get-variable -name createZendeskUsersReqError) ) {
                                remove-variable -Name createZendeskUsersReqError;
                            }
                        }
                        
                        # Check the status of the create Zendesk user request
                        if($WebReqCreateZendeskUsers.StatusCode -ne 201 -and $createZendeskUsersReqError) {
                            # Log it with log4net
                            $log4netLogger.error("a) transformUsersToJSON() | The status code on WebReqCreateZendeskUsers was different from HTTP201 CREATED. Unknown state, cannot continue.");
                            $log4netLogger.error("b) transformUsersToJSON() | The status code returned is: $($WebReqCreateZendeskUsers.StatusCode).");
                            
                            # Clean-up
                            remove-variable -Name createZendeskUsersReqError;
                        }
                    }
                } elseif($null -ne $userUpdatedStatus -and $userUpdatedStatus.length -lt 1) {
                    # Log that the user was determined to not have been [Modified] in a way so that it should be synced to Zendesk.
                    $log4netLoggerDebug.debug("transformUsersToJSON() - UPDATE - | It was determined that the user was not [Modified] in a way that makes it relevant to synchronize it to Zendesk.");            
                } # End of elseIf conditional check on userUpdateStatus
            } # End of condition check on $userOK boolean. 
        } # End of foreach user from AD query on [MODIFIED] state
    } # End of check on transform type.
    
    # Debug log - Log how many users we will try to send to Zendesk
    $log4netLoggerDebug.debug("transformUsersToJSON() - Number of users being send to Zendesk: $($users.users.Count).");
    
    # Check if there is actually any users in the JSON object. Before blindly returning the JSON object to the main script. 
    if($users.users.Count -ge 1) {
        # Convert the users object to JSON & return it
        $usersInJSON = ConvertTo-Json -InputObject $users -Depth 3;
        
        # Return users in JSON format.        
        return $usersInJSON;
    } else {
        # Get data of execution context, in order to know info on caller and ease troubleshooting
        $ExecutionInfo = Get-execution;        
        
        # Log it with log4net - DEBUG
        $log4netLoggerDebug.debug("a) transformUsersToJSON() | No users was transformed to JSON. See previous per user log entries.");        
        $log4netLoggerDebug.debug("b) transformUsersToJSON() | Users variable contains this many users: $($users.users.count)");
        $log4netLoggerDebug.debug("c) transformUsersToJSON() | Execution flow: $($ExecutionInfo.command) - Call references: $($ExecutionInfo.location)");
       
        # Return $null to let caller know that after processing of the incoming users --> no users should be [created] or [updated] on Zendesk.
        return $null;
    } 
} # End of module function declaration

##################################
#### PRIVATE helper functions ####
##################################
function getZendeskOrganization($user, $srcAD) {
    # Determine the ID of the Zendesk organization that the user should belong to
    try {
        $tempOU = getUserOU -adUser $user -srcAD $srcAD; # First get the OU which description contains what is the external_id we can query Zendesk for an org. by 
    } catch {
        # Log it with log4net
        $log4netLogger.error("priv. function getZendeskOrganization() in transformUsersToJSON() | Call to getUserOU failed with: $_");        
    }
    
    if ($null -ne $tempOU) 
    {
        # Debug log
        $log4netLoggerDebug.debug("getZendeskOrganization() inside transformUsersToJSON() | Value of OU tempOU: $tempOU.");
    
        try {
            $ouDescriptionInJSON = transformOuDescriptionToJSON -ou $tempOU;
        } catch {
            # Log it with log4net
            $log4netLogger.error("priv. function getZendeskOrganization() in transformUsersToJSON() | Call to transformOuDescriptionToJSON failed with: $_");        
        }
        
        if ($null -ne $ouDescriptionInJSON) 
        {
            # Define getZendeskOrganization web request vars
            if( $null -eq (get-variable WebReqURI_getZendeskOrganization -ErrorAction SilentlyContinue) ) {
                set-getZendeskOrganization_InvokeWebRequestVars; # Function in zendeskIntegrationConfig module, used to define getZendeskOrganization web request vars
            }
            
            try {
                $WebReqGetZendeskOrgOutput = Invoke-WebRequest -Uri $WebReqURI_getZendeskOrganization -Method $WebReqMethod_POST -Body $ouDescriptionInJSON -ContentType $WebReqContent -ErrorVariable getZendeskOrgOutputReqError;
            } catch {
                # Log it with log4net
                $log4netLogger.error("a) priv. function getZendeskOrganization() in transformUsersToJSON() | Invoke Web request failed on: WebReqURI_getZendeskOrganization, with: $_");        
                $log4netLogger.error("b) priv. function getZendeskOrganization() in transformUsersToJSON() | getZendeskOrganization call Ps error variable: $getZendeskOrgOutputReqError");
            }
            
            # Check the status of the get Zendesk org. request
            if(!$getZendeskOrgOutputReqError) 
            {
                if($WebReqGetZendeskOrgOutput.StatusCode -eq 200) 
                {
                    # Return the Zendesk organization which the user belongs to.
                    return $WebReqGetZendeskOrgOutput;
                } else {
                    # Log it with log4net
                    $log4netLogger.error("a) priv. function getZendeskOrganization() in transformUsersToJSON() | The status code on WebReqGetZendeskOrgOutput was different from HTTP200. Unknown state, cannot continue.");
                    $log4netLogger.error("b) priv. function getZendeskOrganization() in transformUsersToJSON() | The status code returned is: $($WebReqGetZendeskOrgOutput.StatusCode).");
                    throw "priv. function getZendeskOrganization() in transformUsersToJSON() | The statusCode on WebReqGetZendeskOrgOutput was different from 200OK. Unknown state, cannot continue.";
                }
            } else {
                # Log it with log4net
                $log4netLogger.error("priv. function getZendeskOrganization() in transformUsersToJSON() | getZendeskOrganization failed with: $getZendeskOrgOutputReqError.");
                                
                # Clean-up
                Remove-variable -Name getZendeskOrgOutputReqError;
            }
        } # End of if conditional check on $ouDescriptionInJSON
    } # End of if conditional check on $tempOU        
} # End of private function getZendeskOrganization declaration

# Export specific modules/functions outside this script in order to keep certain members private.
Export-ModuleMember -Function transformUsersToJSON;
###################
# FUNCTION - END
###################