################
# Script preparation
################

## Load PSSnapins, modules x functions
Import-Module -Name $PSScriptRoot\modules\zendeskIntegrationConfig -force # Module that configures settings such as vars which is used throughout. 
Import-Module -Name $PSScriptRoot\modules\transformUsersToJSON -force
Import-Module -Name $PSScriptRoot\modules\getUsersInOu -force
Import-Module -Name $PSScriptRoot\modules\determineCompanyModifiedStatus -force
Import-Module -Name $PSScriptRoot\modules\get-companyZendeskOrgID -force
Import-Module -Name $PSScriptRoot\modules\confirm-shouldUserBeIncluded -force # Helper module that determines if an user should be included in the resulting collections going to Zendesk
Import-Module -Name $PSScriptRoot\modules\get-SubOUsOn... -force
Import-Module -Name $PSScriptRoot\modules\process-companyAgainstZendesk -force
Import-Module -Name $PSScriptRoot\modules\process-usersAgainstZendesk -force
Import-Module -Name $PSScriptRoot\..\log4net\initialize-log4net -force
Import-Module -Name $PSScriptRoot\modules\Write-SyncDataXmlFile -force # Module that writes the xml file that contains syncData (date for last sync time)
Import-Module -Name $PSScriptRoot\modules\3rdParty\Send-MailEasily -Force; 

## Variables
$...IsAD = '';
[boolean]$syncSuccess = $true; # Bool to check if a sync run was successful or not.  
$log4NetFilesName = "zendeskIntegration_Ps";
$log4NetLoggerName = "PsZendeskIntegration_Errors";
$log4NetLoggerNameDebug = "PsZendeskIntegration_Debugs";

## Various settings
Set-StrictMode -Version Latest; # Policing ourselves.

#####################
# SCRIPT BODY - START
#####################
function zendeskIntegration_Main() {
<#
.DESCRIPTION
    This is the main part of the Zendesk Integration system. It syncs incoming AD data to Zendesk. This is done via Zendesk's REST API.
.PARAMETER srcAD
    Used to specify the AD source.
.PARAMETER isSandboxMode
    Used when testing. Requests will be send to the test server defined in 'zendeskIntegrationConfig.psm1'
.PARAMETER SpecificCompSyncDistinguishedName
    When running for a specific company.    
.NOTES
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="The source AD which the Zendesk Integration system should process AD objects from.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('','')]
        $srcAD,
        [Parameter(Mandatory=$false, HelpMessage="Switch parameter to define if the script should run in sandbox mode.")]
        [Switch]
        $isSandboxMode,
        [Parameter(Mandatory=$false, HelpMessage="DistinguishedName of a company OU. The company you want to specifically sync.")]
        [ValidateNotNullOrEmpty()]
        $SpecificCompSyncDistinguishedName
    )

    # Set NodeJS endpoint URI
    set-WebReqSrvEndpointVar $isSandboxMode;
    
    # Initiate log4net logger
    $global:log4netLogger = initialize-log4net -log4NetAssemblyPath $PSScriptRoot\..\log4Net\bin\net\4.0\release\log4net.dll -log4NetFilesPath $PSScriptRoot\..\log4net -log4NetFilesName $log4NetFilesName -log4NetLoggerName $log4NetLoggerName;
    $global:log4netLoggerDebug = initialize-log4net -log4NetAssemblyPath $PSScriptRoot\..\log4Net\bin\net\4.0\release\log4net.dll -log4NetFilesPath $PSScriptRoot\..\log4net -log4NetFilesName $log4NetFilesName -log4NetLoggerName $log4NetLoggerNameDebug; 

    # Make the log more viewable.
    $log4netLoggerDebug.debug("-------------------------------------------------------------");
    $log4netLoggerDebug.debug("---- Logging started for synchronization run over $srcAd ----");
    $log4netLoggerDebug.debug("------------------ $((get-date).toString()) -----------------");
    $log4netLoggerDebug.debug("-------------------------------------------------------------");    

    # Before trying to set syncDataFilePath check if it haven't already been set
    if( $null -eq (get-variable syncDataFilePath -ErrorAction SilentlyContinue) ) {
        set-syncDataFilePathVar # Function in zendeskIntegrationConfig module, used to get sync data file variables defined
    }
    
    # Determine if syncData file can be read. If not go into [FULL] sync & vice versa
    try {
        [xml]$syncDataFileContent = Get-Content -Path $syncDataFilePath -ErrorVariable GetSyncDataFileContentErrorVar -ErrorAction Stop;
    } catch {
        write-output "=====";
        write-output "syncData.xml file not found. This is the file used to determine DateTime of last sync.";
        write-output "SYNC MODE IS THEREFORE NOW FULL";
        write-output "=====";
        
        # Log it with log4net
        $log4netLogger.error("Main script | syncData.xml could not be read. Sync is therefore of type [FULL]. Error was: $_");
    }
    
    # Define e-mail related variables
    if ( $null -eq (Get-Variable mailTo -ErrorAction SilentlyContinue) ) {
        set-MailVars;
    }
    
    <# 
        - Get current dateTime. Which is to be used in case [FULL] or one of the [INCREMENTAL] entity syncs successfully finishes.
        We do this to make sure that users or companies possibly [created] or [modified] while the Zendesk sync software is running is
        included the next time a sync is executed.
    #>        
    $currenteSync_dateTime = (get-date).ToString();
    
    if(!$GetSyncDataFileContentErrorVar -and $null -ne (Get-Variable syncDataFileContent -ErrorAction SilentlyContinue) -and $null -eq $SpecificCompSyncDistinguishedName) 
    {
        #####################
        ## [Incremental] sync as time of last sync [COULD] be retrieved
        #####################
        
        ####    
        ## Get OU's/companies [MODIFIED] since last sync (ALSO gets companies [CREATED] since last incremental sync. As the 'whenChanged' AD attribute is the attribute being updated when creating an OU.
        ####
        # Read dateTime data of last sync in the syncData.xml file.
        $lastSync_dateTime = $syncDataFileContent.data.lastSync_Organizations | get-date;
        
        # Check if we got a dateTime obj. --> if $true continue.
        if($lastSync_dateTime.GetType().Name -eq "DateTime") 
        {
            # Control AD source & then set accordingly 
            if($srcAD -eq $...IsAD) {
                set-...AdOuQueries_Incremental; # Function in zendeskIntegrationConfig module, used to get AD Query variables defined
                $OUs_Modified = $...OUs_Modified;
                set-AdDomainVar # This is an exported function in the zendeskIntegrationConfig module - Sets the domain name as we have multiple AD's in play
                $srcDomain = $...AdDomain;
            } else {
                set-...AdOuQueries_OU_Incremental; # Function in zendeskIntegrationConfig module, used to get AD Query variables defined
                $OUs_Modified = $...OUs_Modified;
                set-AdDomainVar # This is an exported function in the zendeskIntegrationConfig module - Sets the domain name as we have multiple AD's in play
                $srcDomain = $...AdDomain;
            }
            
            # Instantiate HASH table to have a proper collection to .add() company OU's to.
            $OUs = @{};            
            
            foreach($ou in Invoke-Command -ScriptBlock $OUs_Modified -ArgumentList $lastSync_dateTime -NoNewScope) {
                # Add the current OU to the HASHtable
                $OUs.Add($ou.external_id, $ou); # OU description is the hashtable key.
            }
            
            # Check to see if we got any OU's --> if $true process OU's.
            if($OUs.count -gt 0) 
            {
                # Get enumerator so that we can iterate over the Hashtable that contains company OU's
                $enumerator = $OUs.GetEnumerator();
                
                # Call private function located inside this main script. To get sub-ou's on ...
                if($srcAD -eq $...IsAD) {
                    $enumerator = get-SubOUsOn... -enumerator $enumerator -lastSync_dateTime $lastSync_dateTime;
                }
                
                ####
                ## [Create] OR [Update] companies on Zendesk. Since last sync.
                ####
                foreach($ou in $enumerator) {
                    # First check if the company has been modified on AD attributes which makes us interested in updating the company on Zendesk
                    #[string]$companyModifiedStatus = determineCompanyModifiedStatus $ou $lastSync_dateTime $srcDomain;
                    
                    #if($companyModifiedStatus -eq 'Modified') {
                        write-output "Current OU: $($ou.value.name)";
                        # Log it with log4net
                        $log4netLoggerDebug.debug("Incremental sync | Main script | Creating or updating: $($ou.value.name)");
                        try {
                            # Call private process-companyAgainstZendesk() to get the company either [created] or [updated]
                            process-companyAgainstZendesk -ou $ou -srcAD $srcAD;
                        } catch {
                            # Log it with log4net
                            $log4netLogger.error("Incremental sync | Main script | Calling process-companyAgainstZendesk failed with: $_");

                            # Set sync to $false as the OU/company was not processed successfully.                            
                            $syncSuccess = $false;

                            # Alert that the OU/company could not be synced successfully to Zendesk.
                            $mailSubject = "Zendesk debug | Main script | Incremental sync | Environment: $srcAD";
                            $mailBodyContent = "Calling process-companyAgainstZendesk for $($ou.value.name), failed with: $_";
                            
                            try {
                                Send-MailEasily -mailTo $mailTo -mailFrom $mailFrom -mailSubject $mailSubject -mailBodyContent $mailBodyContent -mailServer $mailServer;                                                                        
                            } catch {
                                # Log it with log4net
                                $log4netLogger.error("Incremental sync | Main script | Send-MailEasily() failed with: $_.");
                            }
                        }
                    #}
                };
                
                # Write to syncData.xml if the entire sync of OU's was a success.
                if($syncSuccess -eq $true) 
                {
                    # Get current dateTime
                    $syncDataFileContent.data.lastSync_Organizations = $currenteSync_dateTime;
                    
                    # Write it to the syncData.xml file
                    Write-SyncDataXmlFile -syncDataFilePath $syncDataFilePath -xmlcontent $syncDataFileContent;                                            
                }
            } else {
                # Log it with log4net - Nothing to sync.
                $log4netLogger.error("Incremental sync | Main script | No modified OU's was found. no orgs. to sync to Zendesk.");
            }
        } else {
            # Log it with log4net - Couldn't get a dateTime object.
            $log4netLogger.error("Incremental sync | Main script | Couldn't get a dateTime object so we couldn't even try process OU's to see if they should be synced to Zendesk.");
            
            # Alert that the syncData.xml file seems to be corrupted.
            $mailSubject = "Zendesk debug | Main script | Incremental sync | Environment: $srcAD";
            $mailBodyContent = "Couldn't get a dateTime object so we couldn't even try process OU's to see if they should be synced to Zendesk.";
            
            try {
                Send-MailEasily -mailTo $mailTo -mailFrom $mailFrom -mailSubject $mailSubject -mailBodyContent $mailBodyContent -mailServer $mailServer;                                                                        
            } catch {
                # Log it with log4net
                $log4netLogger.error("Incremental sync | Main script | Send-MailEasily() failed with: $_.");
            }
        }
        
        ####    
        ## [Create] OR [Update] users on Zendesk. Since last sync. 
        ####
        
        # Define users web request vars
        set-createZendeskUsers_InvokeWebRequestVars; # Function in zendeskIntegrationConfig module, used to define createZendeskUsers web request vars
        set-updateZendeskUsers_InvokeWebRequestVars;
        
        #### [CREATE] users 
               
        # Read dateTime data of last sync in the syncData.xml file.
        $lastSync_dateTime = $syncDataFileContent.data.lastSync_CreatedUsers | get-date;
        
        write-output "-Trying to sync [CREATED] users to Zendesk.";        
        
        # Check if we got a dateTime obj. --> if $true continue.
        if($lastSync_dateTime.GetType().Name -eq "DateTime") 
        {
            # Determine which AD is the source AD & set variables accordingly. !! The variables have to be set for each OU coming in. To update the lastsync_datetime value.
            if($srcAD -eq '') 
            { 
                set-...AdOuQueries_Users_Incremental # This is an exported function in the zendeskIntegrationConfig module
                $GetActiveAndRegularUsers = $...Users_Created;
            } elseif($srcAD -eq '') {
                set-...AdOuQueries_Users_Incremental; # This is an exported function in the zendeskIntegrationConfig module
                $GetActiveAndRegularUsers = $...Users_Created;
            }
            
            # Get users [CREATED] since last successful sync.
            try {
                [array]$usersToBeCreated = Invoke-Command -ScriptBlock $GetActiveAndRegularUsers -ArgumentList $lastSync_dateTime -NoNewScope -ErrorAction Stop;
            } catch {
                # Log it with log4net.
                $log4netLogger.error("Incremental sync | Main script | Invoke-command to get created users failed with: $_.");
            }
            
            # Check that we got any users
            if($null -ne $usersToBeCreated -and $usersToBeCreated.count -ge 1) 
            {                        
                # Check if number of users is above 100. If so we will have to give Zendesk max 100, therefore split into smaller collections.
                # See: https://developer.zendesk.com/rest_api/docs/core/users#create-or-update-many-users (Accepts an array of up to 100 user objects)
                if($usersToBeCreated.count -gt 100) {
                    $usersToBeCreatedEnumerator = $usersToBeCreated.GetEnumerator();
                    $tempHash = @{};
                    while($usersToBeCreatedEnumerator.MoveNext()) {
                        if($tempHash.Count -gt 0) {
                            $tempHash = @{};
                        }
                        
                        # add 100 users to the tempHash collection - to match Zendesk 'create many users - endpoint' REST API  requirements
                        $keyCounter = 0;
                        for($i = 1; $i -le 99; $i++) {
                            $currentElement = $usersToBeCreatedEnumerator.Current;
                            if($currentElement) {
                                $tempHash.add($keyCounter, $currentElement);
                                $keyCounter++;
                            } else {
                                break
                            }
                            $usersToBeCreatedEnumerator.MoveNext() | Out-Null;
                        }
                        
                        # Get the last element of the loop.
                        $currentElement = $usersToBeCreatedEnumerator.Current;
                        if($currentElement) {
                            $tempHash.add($keyCounter, $currentElement)
                        }

                        # Transform users to be created to JSON
                        $usersToBeCreatedonZendeskInJSON = transformUsersToJSON -userHASHCollToTransform $tempHash -transformType 'create' -srcAD $srcAD;

                        if($null -ne $usersToBeCreatedonZendeskInJSON) 
                        {
                            # We now have 100 users or below. We can go ahead and sent them to Zendesk.
                            try {
                                # [Create] users on Zendesk
                                Invoke-WebRequest -Uri $WebReqURI_createZendeskUsers -Method $WebReqMethod_POST -Body ([System.Text.Encoding]::UTF8.GetBytes($usersToBeCreatedonZendeskInJSON)) -ContentType $WebReqContentUsers -ErrorVariable createZendeskUsersReqError;
                            } catch {
                                # Log it with log4net
                                $log4netLogger.error("a) Incremental sync | Main script | Sending users to createZendeskUsers ExpressJS endpoint failed with: $_");
                                $log4netLogger.error("b) Incremental sync | Main script | createZendeskUsers call Ps error variable: $createZendeskUsersReqError");
                                
                                # Could not update zendesk users in transformUsersToJSON module
                                $syncSuccess = $false;
                    
                                # Clean-up
                                remove-variable -Name createZendeskUsersReqError;
                            }
                        }
                    } 
                } else {
                    <# 
                        - Amount of users is at 100 or below. We can go ahead and sent them to Zendesk.
                    #>

                    # First make the users into a hashtable collection. For easier data handling down the 'road'
                    $usersToBeCreatedEnumerator = $usersToBeCreated.GetEnumerator();
                    $tempHash = @{};
                    $keyCounter = 0;
                    foreach($user in $usersToBeCreatedEnumerator) {
                        $tempHash.add($keyCounter, $user);
                        $keyCounter++;
                    }
                    
                    # Transform users to be created on Zendesk into JSON
                    $usersToBeCreatedonZendeskInJSON = transformUsersToJSON -userHASHCollToTransform $tempHash -transformType 'create' -srcAD $srcAD;

                    if ($null -ne $usersToBeCreatedonZendeskInJSON) 
                    {
                        try {
                            # [Create] users on Zendesk
                            Invoke-WebRequest -Uri $WebReqURI_createZendeskUsers -Method $WebReqMethod_POST -Body ([System.Text.Encoding]::UTF8.GetBytes($usersToBeCreatedonZendeskInJSON)) -ContentType $WebReqContentUsers -ErrorVariable createZendeskUsersReqError;
                        } catch {
                            # Log it with log4net
                            $log4netLogger.error("a) Incremental sync | Main script | Sending users to createZendeskUsers ExpressJS endpoint failed with: $_");
                            $log4netLogger.error("b) Incremental sync | Main script | createZendeskUsers call Ps error variable: $createZendeskUsersReqError");
                            
                            # Could not create zendesk users in transformUsersToJSON module
                            $syncSuccess = $false;
                
                            # Clean-up
                            remove-variable -Name createZendeskUsersReqError;
                        }
                    }                    
                }

                # Write to syncData.xml if the entire sync of created users was a success.
                if($syncSuccess -eq $true) {
                    # Get current dateTime
                    $syncDataFileContent.data.lastSync_CreatedUsers = $currenteSync_dateTime;
                    
                    # Write it to the syncData.xml file
                    Write-SyncDataXmlFile -syncDataFilePath $syncDataFilePath -xmlcontent $syncDataFileContent;                                            
                }
            } else {
                # Log it with log4net
                $log4netLogger.error("Incremental sync | Main script | No users to [create]. No users was found to be [created] since last incremental sync.");
            } # End of check on $usersToBeCreated.count
        } else {
            # Log it with log4net - Couldn't get a dateTime object.
            $log4netLogger.error("Incremental sync | Main script | [CREATE] users | Couldn't get a dateTime object so we couldn't even try process user's to see if they should be synced to Zendesk.");
            
            # Alert that the syncData.xml file seems to be corrupted.
            $mailSubject = "Zendesk debug | Main script | Incremental sync | [CREATE] users | Environment: $srcAD";
            $mailBodyContent = "Couldn't get a dateTime object so we couldn't even try process user's to see if they should be synced to Zendesk.";
            
            try {
                Send-MailEasily -mailTo $mailTo -mailFrom $mailFrom -mailSubject $mailSubject -mailBodyContent $mailBodyContent -mailServer $mailServer;                                                                        
            } catch {
                # Log it with log4net
                $log4netLogger.error("Incremental sync | Main script | Send-MailEasily() failed with: $_.");
            }                                                                                    
        }
        
        #### [UPDATE] users 
               
        # Read dateTime data of last sync in the syncData.xml file.
        $lastSync_dateTime = $syncDataFileContent.data.lastSync_ModifiedUsers | get-date;
        
        write-output "-Trying to sync [UPDATED] users to Zendesk.";
                
        # Check if we got a dateTime obj. --> if $true continue.
        if($lastSync_dateTime.GetType().Name -eq "DateTime") 
        {                
            # Determine which AD is the source AD & set variables accordingly. !! The variables have to be set for each OU coming in. To update the lastsync_datetime value.
            if($srcAD -eq '') 
            { 
                set-...AdOuQueries_Users_Incremental; # This is an exported function in the zendeskIntegrationConfig module
                $GetActiveAndRegularUsers = $...Users_Modified;
            } elseif($srcAD -eq '...') {
                set-...AdOuQueries_Users_Incremental; # This is an exported function in the zendeskIntegrationConfig module
                $GetActiveAndRegularUsers = $...Users_Modified;
            }

            # Get users [UPDATED] since last successful sync.
            try {
                [array]$usersToBeUpdated = Invoke-Command -ScriptBlock $GetActiveAndRegularUsers -ArgumentList $lastSync_dateTime -NoNewScope -ErrorAction Stop;
            } catch {
                # Log it with log4net.
                $log4netLogger.error("Incremental sync | Main script | Invoke-command to get updated users failed with: $_.");
            }

            # Check that we got any users
            if($null -ne $usersToBeUpdated -and $usersToBeUpdated.count -ge 1)
            {
                # Check if number of users is above 100. If so we will have to give Zendesk max 100, therefore split into smaller collections.
                # See: https://developer.zendesk.com/rest_api/docs/core/users#create-or-update-many-users (Accepts an array of up to 100 user objects)
                if($usersToBeUpdated.count -gt 100) {
                    $usersToBeUpdatedEnumerator = $usersToBeUpdated.GetEnumerator();
                    $tempHash = @{};
                    while($usersToBeUpdatedEnumerator.MoveNext()) {
                        if($tempHash.Count -gt 0) {
                            $tempHash = @{};
                        }
                        
                        # add 100 users to the tempHash collection - to match Zendesk 'update many users - endpoint' REST API  requirements
                        $keyCounter = 0;
                        for($i = 1; $i -le 99; $i++) {
                            $currentElement = $usersToBeUpdatedEnumerator.Current;
                            if($currentElement) {
                                $tempHash.add($keyCounter, $currentElement);
                                $keyCounter++;
                            } else {
                                break
                            }
                            $usersToBeUpdatedEnumerator.MoveNext() | Out-Null;
                        }
                        
                        # Get the last element of the loop.
                        $currentElement = $usersToBeUpdatedEnumerator.Current;
                        if($currentElement) {
                            $tempHash.add($keyCounter, $currentElement)
                        }

                        # Transform users to be created to JSON - transformUsersToJSON() returns $null if no users was transformed.
                        $usersToBeUpdatedonZendeskInJSON = transformUsersToJSON -userHASHCollToTransform $tempHash -transformType 'update' -srcAD $srcAD -lastSync_dateTime $lastSync_dateTime;

                        if ($null -ne $usersToBeUpdatedonZendeskInJSON) 
                        {
                            # We now have 100 users or below. We can go ahead and send them to Zendesk.
                            try {
                                # [Update] users on Zendesk
                                Invoke-WebRequest -Uri $WebReqURI_updateZendeskUsers -Method $WebReqMethod_POST -Body ([System.Text.Encoding]::UTF8.GetBytes($usersToBeUpdatedonZendeskInJSON)) -ContentType $WebReqContentUsers -ErrorVariable updateZendeskUsersReqError;
                            } catch {
                                # Log it with log4net
                                $log4netLogger.error("a) Incremental sync | Main script | Sending users to updateZendeskUsers ExpressJS endpoint failed with: $_");
                                $log4netLogger.error("b) Incremental sync | Main script | updateZendeskUsers call Ps error variable: $updateZendeskUsersReqError");
                                
                                # Could not update zendesk users in transformUsersToJSON module
                                $syncSuccess = $false;
                    
                                # Clean-up
                                remove-variable -Name updateZendeskUsersReqError;
                            }
                        }
                    } 
                } else {
                    <# 
                        - Amount of users is at 100 or below. We can go ahead and send them to Zendesk.
                    #>

                    # First make the users into a hashtable collection. For easier data handling down the 'road'
                    $usersToBeUpdatedEnumerator = $usersToBeUpdated.GetEnumerator();
                    $tempHash = @{};
                    $keyCounter = 0;
                    foreach($user in $usersToBeUpdatedEnumerator) {
                        $tempHash.add($keyCounter, $user);
                        $keyCounter++;
                    }
                    
                    # Transform users to be updated on Zendesk into JSON - transformUsersToJSON() returns $null if no users was transformed.
                    $usersToBeUpdatedonZendeskInJSON = transformUsersToJSON -userHASHCollToTransform $tempHash -transformType 'update' -srcAD $srcAD -lastSync_dateTime $lastSync_dateTime;
                    
                    if ($null -ne $usersToBeUpdatedonZendeskInJSON) {
                        try {
                            # [Update] users on Zendesk
                            Invoke-WebRequest -Uri $WebReqURI_updateZendeskUsers -Method $WebReqMethod_POST -Body ([System.Text.Encoding]::UTF8.GetBytes($usersToBeUpdatedonZendeskInJSON)) -ContentType $WebReqContentUsers -ErrorVariable updateZendeskUsersReqError;
                        } catch {
                            # Log it with log4net
                            $log4netLogger.error("a) Incremental sync | Main script | Sending users to updateZendeskUsers ExpressJS endpoint failed with: $_");
                            $log4netLogger.error("b) Incremental sync | Main script | updateZendeskUsers call Ps error variable: $updateZendeskUsersReqError");
                            
                            # Could not update zendesk users in transformUsersToJSON module
                            $syncSuccess = $false;
                
                            # Clean-up
                            remove-variable -Name updateZendeskUsersReqError;
                        }
                    }
                }

                # Write to syncData.xml if the entire sync of updated users was a success.
                if($syncSuccess -eq $true) {
                    # Get current dateTime
                    $syncDataFileContent.data.lastSync_ModifiedUsers = $currenteSync_dateTime;
                    
                    # Write it to the syncData.xml file
                    Write-SyncDataXmlFile -syncDataFilePath $syncDataFilePath -xmlcontent $syncDataFileContent;                                            
                }
            } else {
                # Log it with log4net
                $log4netLogger.error("Incremental sync | Main script | No users to [update]. No users was found to be [updated] since last incremental sync.");
            } # End of check on $usersToBeUpdated.count
        } else {
            # Log it with log4net - Couldn't get a dateTime object.
            $log4netLogger.error("Incremental sync | Main script | [UPDATE] users | Couldn't get a dateTime object so we couldn't even try process user's to see if they should be synced to Zendesk.");
            
            # Alert that the syncData.xml file seems to be corrupted.
            $mailSubject = "Zendesk debug | Main script | Incremental sync | [UPDATE] users | Environment: $srcAD";
            $mailBodyContent = "Couldn't get a dateTime object so we couldn't even try process user's to see if they should be synced to Zendesk.";
            
            try {
                Send-MailEasily -mailTo $mailTo -mailFrom $mailFrom -mailSubject $mailSubject -mailBodyContent $mailBodyContent -mailServer $mailServer;                                                                        
            } catch {
                # Log it with log4net
                $log4netLogger.error("Incremental sync | Main script | Send-MailEasily() failed with: $_.");
            }                                                                                            
        }
    } else {
        #####################
        ## [Full] sync as time of last sync could [NOT] be retrieved or this is the first time running the Zendesk integration system
        ##################### 
        # Before trying to set AD OU query vars. check if they haven't already been set
        if( $null -eq (get-variable GetOUs -ErrorAction SilentlyContinue) ) 
        {
            # Control AD source & then set the AD OU query vars accordingly
            if($null -ne $SpecificCompSyncDistinguishedName -and $SpecificCompSyncDistinguishedName.length -gt 0) 
            {
                set-SpecificCompSync_OuQuery $SpecificCompSyncDistinguishedName;
                write-output "specific comp dn: " $SpecificCompSyncDistinguishedName; 
                $GetOUs = $SpecificCompOu;
            } elseif($srcAD -eq $...IsAD) {
                set-...Ad_MainOuQueries_Full; # Function in zendeskIntegrationConfig module, used to get AD Query variables defined
                $GetOUs = $...OUs_Full;
            } else {
                set-...AdOuQueries_OU_Full; # Function in zendeskIntegrationConfig module, used to get AD Query variables defined
                $GetOUs = $...OUs_Full;
            }
        }
        
        ####
        ## [Create] OR [Update] companies on Zendesk 
        ####

        #### Gather OU's/companies that are to be made into Zendesk orgs.
        $OUs = @{}; # Instantiate HASH table to have a proper collection to .add() main company OU's to.
        
        # Get OU's
        foreach($ou in Invoke-Command -ScriptBlock $GetOUs -NoNewScope) {
            # OU description is the hashtable key.
            $OUs.Add($ou.external_id, $ou);
        }

        # Get enumerator so that we can iterate over the Hashtable that contains company OU's
        $enumerator = $OUs.GetEnumerator();

        # Call private function located inside this main script. To get sub-ou's on ...
        if($srcAD -eq $...IsAD) {
            $syncType = 'full';
            $enumerator = get-SubOUsOn... -enumerator $enumerator -syncType $syncType;
        }
        
        # Run over each OU with the enumerator
        foreach($ou in $enumerator) {
            # Call process-companyAgainstZendesk() to have the company either [created] or [updated] --> RETURNS Zendesk Org. id of processed company. As it will be used when processing users.
            try {
                Write-Output "MAIN SCRIPT | FULL SYNC | Running over next main OU: $($ou.value.name)";
                # Log it with log4net
                $log4netLoggerDebug.debug("FULL SYNC | Main script | Creating or updating: $($ou.value.name)");                
                
                $companyZendeskOrgID = process-companyAgainstZendesk -ou $ou -srcAD $srcAD;
            } catch {
                # Log it with log4net
                $log4netLogger.error("Full sync | Main script | Calling process-companyAgainstZendesk failed with: $_");
                
                if($null -eq $SpecificCompSyncDistinguishedName)
                {                                
                    # Set sync to $false as the OU/company was not processed successfully.
                    $syncSuccess = $false;
                }

                # Alert that the OU/company could not be synced successfully to Zendesk.
                $mailSubject = "Zendesk debug | Main script | Full sync | Environment: $srcAD";
                $mailBodyContent = "Calling process-companyAgainstZendesk for $($ou.value.name), failed with: $_";
                
                try {
                    Send-MailEasily -mailTo $mailTo -mailFrom $mailFrom -mailSubject $mailSubject -mailBodyContent $mailBodyContent -mailServer $mailServer;                                                                        
                } catch {
                    # Log it with log4net
                    $log4netLogger.error("Full sync | Main script | Send-MailEasily() failed with: $_.");
                }                                                           
            }
            
            # Make sure that we retrieved a Zendesk Org. ID for the current Company.
            if($companyZendeskOrgID) {
                # Call process-usersAgainstZendesk() to have users in the company OU [created] or [updated]
                try {
                    process-usersAgainstZendesk -ou $ou -companyZendeskOrgID $companyZendeskOrgID -srcAD $srcAD;
                } catch {
                    if($null -eq $SpecificCompSyncDistinguishedName)
                    {
                        # Set sync to $false as the users in the company was not processed successfully.                    
                        $syncSuccess = $false;
                    }
                    
                    # Log it with log4net
                    $log4netLogger.error("Full sync | Main script | Calling process-usersAgainstZendesk failed with: $_");
                    
                    # Alert that the OU/company could not be synced successfully to Zendesk.
                    $mailSubject = "Zendesk debug | Main script | Full sync | Environment: $srcAD";
                    $mailBodyContent = "Calling process-usersAgainstZendesk for $($ou.value.name), failed with: $_";

                    try {
                        Send-MailEasily -mailTo $mailTo -mailFrom $mailFrom -mailSubject $mailSubject -mailBodyContent $mailBodyContent -mailServer $mailServer;                                                                        
                    } catch {
                        # Log it with log4net
                        $log4netLogger.error("Full sync | Main script | Send-MailEasily() failed with: $_.");
                    }                                                                               
                }
            } else {
                # Log it with log4net
                $log4netLogger.error("Full sync | Main script (Main OU's) | No ID on company $($ou.value.name) was retrieved from Zendesk. process-companyAgainstZendesk likely failed.");                
            }
        } # End of foreach on enumerator containing OU's
        
        # Run over OU's which was previously discarded if any was found & the source AD is '...'    
        if($srcAD -eq $...IsAD -and $DiscardedOUs.count -gt 0) {
            ####
            ## [Create] OR [Update] users in discarded OU's on Zendesk  
            ####
            $DiscardedOUsEnumerator = $DiscardedOUs.GetEnumerator();
            
            foreach($ou in $DiscardedOUsEnumerator) {
                $companyZendeskOrgID = get-companyZendeskOrgID $ou; # Private helper function in this script

                # Make sure that we retrieved a Zendesk Org. ID for the current Company.
                if($companyZendeskOrgID) {
                    Write-Output "company zendesk id: $companyZendeskOrgID";  
                    Write-Output "MAIN SCRIPT: Running over next discarded OU to create users: $($ou.name)";
                    
                    try {
                        process-usersAgainstZendesk -ou $ou -companyZendeskOrgID $companyZendeskOrgID -srcAD $srcAD;
                    } catch {
                        if($null -eq $SpecificCompSyncDistinguishedName)
                        {
                            # Set sync to $false as the users in the company was not processed successfully.                                            
                            $syncSuccess = $false;
                        }
                        
                        # Log it with log4net
                        $log4netLogger.error("Full sync | Main script | Users in Discareded OU's | Calling process-usersAgainstZendesk failed with: $_");
                        
                        # Alert that the OU/company could not be synced successfully to Zendesk.
                        $mailSubject = "Zendesk debug | Main script | Full sync | Environment: $srcAD";
                        $mailBodyContent = "Calling process-usersAgainstZendesk for $($ou.name), failed with: $_";

                        try {
                            Send-MailEasily -mailTo $mailTo -mailFrom $mailFrom -mailSubject $mailSubject -mailBodyContent $mailBodyContent -mailServer $mailServer;                                                                        
                        } catch {
                            # Log it with log4net
                            $log4netLogger.error("Full sync | Main script | Send-MailEasily() failed with: $_.");
                        }                                                                                                                           
                    }
                } else {
                    # Log it with log4net
                    $log4netLogger.error("Full sync | Main script (Discarded OU's) | No ID on company $($ou.name) was retrieved from Zendesk. get-companyZendeskOrgID likely failed.");                
                }
            } # End of foreach on enumerator containing discarded OU's
        }; # End of condition check on presence of discardedOU's'

        # (Whitelisted OU's) - Users in OU's with OLD in their name & OU's tagged with 'DoCreateZendeskUsers' in their st (State) AD attribute.
        if($srcAD -eq $...IsAD -and $null -eq $SpecificCompSyncDistinguishedName) {
            foreach($ou in Invoke-Command -ScriptBlock $...WhitelistedOUs_Full -NoNewScope) {
                $companyZendeskOrgID = get-companyZendeskOrgID $ou; # Private helper function in this script

                # Make sure that we retrieved a Zendesk Org. ID for the current Company.
                if($companyZendeskOrgID) {
                    Write-Output "company zendesk id: " $companyZendeskOrgID;  
                    Write-Output "MAIN SCRIPT: Running over next whitelisted OU: $ou.name";
                                    
                    try {
                        process-usersAgainstZendesk -ou $ou -companyZendeskOrgID $companyZendeskOrgID -srcAD $srcAD;
                    } catch {
                        if($null -eq $SpecificCompSyncDistinguishedName)
                        {
                            # Set sync to $false as the users in the company was not processed successfully.                                                                    
                            $syncSuccess = $false;
                        }
                        
                        # Log it with log4net
                        $log4netLogger.error("Main script | Users in whitelisted OU's | Full sync | Calling process-usersAgainstZendesk failed with: $_");

                        # Alert that the OU/company could not be synced successfully to Zendesk.
                        $mailSubject = "Zendesk debug | Main script | Full sync | Environment: $srcAD";
                        $mailBodyContent = "Calling process-usersAgainstZendesk for $($ou.name), failed with: $_";

                        try {
                            Send-MailEasily -mailTo $mailTo -mailFrom $mailFrom -mailSubject $mailSubject -mailBodyContent $mailBodyContent -mailServer $mailServer;                                                                        
                        } catch {
                            # Log it with log4net
                            $log4netLogger.error("Full sync | Main script | Send-MailEasily() failed with: $_.");
                        }                                                                                                                                                                       
                    }
                } else {
                    # Log it with log4net
                    $log4netLogger.error("Main script (Whitelisted OU's) | Full sync | No ID on company $($ou.name) was retrieved from Zendesk. get-companyZendeskOrgID likely failed.");                
                }                    
            }; # End of foreach on AD query returning whitelisted OU's & processing users
        }; # End of condition check on source AD is '...'   
        
        <# 
          - Write to syncData file - with which we determine the type of sync ([incremental] or [full]) on each invocation of this script.
          Only if the [full] sync was completed successfully in its entirety & we are not doing a specific comp. sync.
        #>
        if($syncSuccess -eq $true -and $null -eq $SpecificCompSyncDistinguishedName) {
            # First initialize the syncData.xml file.
            [boolean]$writeSuccess = Write-SyncDataXmlFile -initializeSyncDataXmlFile -syncDataFilePath $syncDataFilePath;
            
            # Check if the syncData.xml file initialization succeeded.
            if($writeSuccess -eq $true) {
                # Get the content of the file
                [xml]$syncDataFileContent = Get-Content -Path $syncDataFilePath;              
            
                # Now get current dateTime & set it for the different entities (companies and users modified or created).
                $syncDataFileContent.data.lastSync_Organizations = $currenteSync_dateTime;
                $syncDataFileContent.data.lastSync_CreatedUsers = $currenteSync_dateTime;
                $syncDataFileContent.data.lastSync_ModifiedUsers = $currenteSync_dateTime;
                
                # Write to the syncData.xml file.
                Write-SyncDataXmlFile -syncDataFilePath $syncDataFilePath -xmlcontent $syncDataFileContent;                
            } else {
                # Log it with log4net
                $log4netLogger.error("Main script | Full sync | The syncData.xml file was NOT updated successfully.");
                
                # ALERT that the syncData.xml file was NOT updated successfully.
                $mailSubject = "Zendesk debug | Main script | Full sync | Environment: $srcAD";
                $mailBodyContent = "The syncData.xml file was NOT updated successfully.";
                
                try {
                    Send-MailEasily -mailTo $mailTo -mailFrom $mailFrom -mailSubject $mailSubject -mailBodyContent $mailBodyContent -mailServer $mailServer;                                                                        
                } catch {
                    # Log it with log4net
                    $log4netLogger.error("Full sync | Main script | Send-MailEasily() failed with: $_.");
                }
            }
        }
        
        if($null -ne (get-variable DiscardedOUs -ErrorAction SilentlyContinue) ) 
        {
            # Clean up
            remove-variable DiscardedOUs -Scope 2;
        }
    } # End of conditional check on $syncDataFileContent
    
    # Clean up
    [log4net.logmanager]::Shutdown() # Shutdown the log4net software properly.    
} # End of zendeskIntegration_Main function declaration - The overall function in this file.

# Export specific modules/functions outside this script in order to keep certain members private.
Export-ModuleMember -Function zendeskIntegration_Main;            
###################
# SCRIPT BODY - END
###################