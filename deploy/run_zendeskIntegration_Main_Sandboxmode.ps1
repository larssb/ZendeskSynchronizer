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

zendeskIntegration_Main -srcAD 'DEFINE SOURCE AD HERE' -isSandboxMode;

###################
# SCRIPT BODY - END
###################