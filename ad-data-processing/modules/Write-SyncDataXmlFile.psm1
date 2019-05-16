################
# Script preparation
################

## Load PSSnapins, modules x functions
Import-Module -Name $PSScriptRoot\3rdParty\ExecutionInfo -force;
Import-Module -Name $PSScriptRoot\3rdParty\Send-MailEasily -Force;
Import-Module -Name $PSScriptRoot\zendeskIntegrationConfig -force # Module that configures settings such as vars which is used throughout. 

#####################
# FUNCTION - START
#####################
function Write-SyncDataXmlFile() {
<#
.DESCRIPTION
    This module defines xml data used to write sync data dateTime info to a xml file. This file is used to get the last dateTime
    of a sync.
    
    If the file does not exist a file is created and the necessary XML content is created.
.PARAMETER syncDataFilePath
    The path that the syncData.xml file should be written to.
.PARAMETER xmlcontent
    The xml content to be written to the syncData.xml file.   
.EXAMPLE
    Write-SyncDataXmlFile -syncDataFilePath $syncDataFilePath;
.NOTES
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="The path to write the syncData.xml file to.")]
        [ValidateNotNullOrEmpty()]
        $syncDataFilePath,
        [Parameter(Mandatory=$false, ParameterSetName="initializeXmlFile", HelpMessage="Specified if the syncData.xml file should be initialized.")]
        [ValidateNotNullOrEmpty()]
        [switch]$initializeSyncDataXmlFile,
        [Parameter(Mandatory=$false, ParameterSetName="updateXmlFile", HelpMessage="The content containing the data that the syncData.xml file hould be updated with.")]
        [ValidateNotNullOrEmpty()]
        $xmlcontent
    )
##
# Script execution from here on out
##
    # Define e-mail related variables - before we call a matching private function in this script.
    if ( $null -eq (Get-Variable mailTo -ErrorAction SilentlyContinue) ) {
        set-MailVars;
    }

    # Check if Write-SyncDataXmlFile was called with the -initializeSyncDataXmlFile parameter, if so --> initialize. 
    if($initializeSyncDataXmlFile) {
        initializeSyncDataXmlFile -syncDataFilePath $syncDataFilePath;
    }
    
    # Check if Write-SyncDataXmlFile was called with the -xmlcontent parameter, if so --> update the syncData.xml file with the incoming data.
    if($xmlcontent) {
        updateSyncDataXmlFile -xmlcontent $xmlcontent -syncDataFilePath $syncDataFilePath;
    }
}


####
# PRIVATE HELPER FUNCTIONS
####
function initializeSyncDataXmlFile($syncDataFilePath) {
<#
.DESCRIPTION
    Private helper function that initializes the syncData.xml file.
.PARAMETER syncDataFilePath
    The path that the syncData.xml file should be written to.
.EXAMPLE
    initializeSyncDataXmlFile -syncDataFilePath $syncDataFilePath;
#>    
    # Define the XML content to be written to a syncData.xml file
    $xmlContent = @"
<DATA>
    <lastSync_Organizations></lastSync_Organizations>
    <lastSync_CreatedUsers></lastSync_CreatedUsers>
    <lastSync_ModifiedUsers></lastSync_ModifiedUsers>    
</DATA>   
"@
    try {
        # Write the content to the syncData.xml file.
        Set-Content -LiteralPath $syncDataFilePath -Value $xmlContent -force;
        
        # Return true to inform caller that the syncData.xml file was initiliazed successfully.
        $true;         
    } catch {
        # Get data of execution context, in order to know info on caller and ease troubleshooting
        $ExecutionInfo = Get-execution;
        
        # Log it with log4net
        $log4netLogger.error("Write-SyncDataXmlFile func() | Could not write to syncData.xml, the request failed with: $_");
        $log4netLogger.error("Write-SyncDataXmlFile func() | Execution flow: $($ExecutionInfo.command) - Call references: $($ExecutionInfo.location)");
    }
}

function updateSyncDataXmlFile($xmlcontent, $syncDataFilePath) {
<#
.DESCRIPTION
    Private helper function that updates the syncData.xml file with the dateTime data of an incremental sync.
.PARAMETER xmlcontent
    The xml content to be written to the syncData.xml file.
.PARAMETER syncDataFilePath
    The path that the syncData.xml file should be written to.  
.EXAMPLE
    updateSyncDataXmlFile -xmlcontent $xmlcontent -syncDataFilePath $syncDataFilePath;
#>
    try {
        # Write the content to the syncData.xml file.
        Set-Content -LiteralPath $syncDataFilePath -Value $xmlcontent.get_OuterXml() -Force;
    } catch {
        # Get data of execution context, in order to know info on caller and ease troubleshooting
        $ExecutionInfo = Get-execution;
        
        # Log it with log4net
        $log4netLogger.error("Write-SyncDataXmlFile func() | Could not write to syncData.xml, the request failed with: $_");
        $log4netLogger.error("Write-SyncDataXmlFile func() | Execution flow: $($ExecutionInfo.command) - Call references: $($ExecutionInfo.location)");
        
        # Alert that we could not to the syncData.xml file successfully.
        $mailSubject = "Zendesk debug | Write-SyncDataXmlFile script - server: $($env:COMPUTERNAME)";
        $mailBodyContent = "Could not write to syncData.xml, the request failed with: $_ `
                            ---- | Execution flow: $($ExecutionInfo.command) - Call references: $($ExecutionInfo.location)";
        Send-MailEasily -mailTo $mailTo -mailFrom $mailFrom -mailSubject $mailSubject -mailBodyContent $mailBodyContent -mailServer $mailServer;
    }
}

Export-ModuleMember -Function Write-SyncDataXmlFile;
###################
# FUNCTION - END
###################