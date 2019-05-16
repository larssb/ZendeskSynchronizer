<#
    - Script description
    This is the script that invokes the main Zendesk Integration script. The script that gathers data from AD --> sends it to ExpressJS --> which in turn
	communicates with Zendesk.
#>
################
# Script preparation
################

## Load PSSnapins, modules x functions
Import-Module ..\ProcessDataFromADs\zendeskIntegration_Main.psm1 -force;

#####################
# SCRIPT BODY - START
##################### 

$SelectedCompanyOU = Get-ADOrganizationalUnit -Filter * | Select-Object Name,DistinguishedName | Out-GridView -Title "Select the company OU that you want to specifically sync to Zendesk" -OutputMode Single;
$CompanyDistinguishedName = " '$($SelectedCompanyOU.DistinguishedName)' ";

zendeskIntegration_Main -srcAD 'DEFINE SOURCE AD' -isSandboxMode -SpecificCompSyncDistinguishedName $CompanyDistinguishedName;

###################
# SCRIPT BODY - END
###################