<#
    - Module description:
    This module configures all necessary variables, settings and so forth for the PowerShell part of the Zendesk Integration system.
#>

#### [PRIVATE VARS] ####
$...AdSearchBase = '';
$...ClassicC5ORegEx =  'K\d+,S[0-1],E[0-1]';

#### [PUBLIC FUNCTIONS] ####
	##
	# INVOKE-WEBREQUEST VARS
	##
							################### | GENERALLY | ###################
function set-WebReqSrvEndpointVar($isSandboxMode) {
	# Configure the correct endpoint based on 
	if($isSandboxMode -eq $true) {
		New-Variable -Name WebReq_SrvEndpoint -Value "http://outest08:8080/" -scope 2 -Force; # URI of the sandbox NodeJS server endpoint serving the ExpressJS web route framework
	} else {
		New-Variable -Name WebReq_SrvEndpoint -Value "http://batch04:8080/" -scope 2 -Force; # URI of the production NodeJS server endpoint serving the ExpressJS web route framework
	} 
}								
	
							################### | COMPANIES / ORGANIZATIONS | ################### 	
function set-getZendeskOrganization_InvokeWebRequestVars() {
	New-Variable -Name WebReqURI_getZendeskOrganization -Value "$WebReq_SrvEndpoint`getZendeskOrganization" -Scope 2;
	set-invokeWebRequestPostVars;
	set-invokeWebRequestContentVars;
}

function set-createZendeskOrg_InvokeWebRequestVars() {
	New-Variable -Name WebReqURI_createZendeskOrg -Value "$WebReq_SrvEndpoint`createZendeskOrg" -Scope 2;
	set-invokeWebRequestPostVars;
	set-invokeWebRequestContentVars;
}

function set-updateZendeskOrg_InvokeWebRequestVars() {
	New-Variable -Name WebReqURI_updateZendeskOrg -Value "$WebReq_SrvEndpoint`updateZendeskOrg" -Scope 2;
	set-invokeWebRequestPutVars;
	set-invokeWebRequestContentVars;
}

							################### | USERS | ###################
function set-createZendeskUsers_InvokeWebRequestVars() {
	New-Variable -Name WebReqURI_createZendeskUsers -Value "$WebReq_SrvEndpoint`createZendeskUsers" -Scope 2;
	set-invokeWebRequestPostVars;
	set-invokeWebRequestContentVarsUsers;
}

function set-getZendeskUser_InvokeWebRequestVars() {
	New-Variable -Name WebReqURI_getZendeskUser -Value "$WebReq_SrvEndpoint`getZendeskUser" -Scope 2;
	set-invokeWebRequestPostVars;
	set-invokeWebRequestContentVars;
}

function set-updateZendeskUsers_InvokeWebRequestVars() {
	New-Variable -Name WebReqURI_updateZendeskUsers -Value "$WebReq_SrvEndpoint`updateZendeskUsers" -Scope 2 -Force;
	set-invokeWebRequestPostVars;
	set-invokeWebRequestContentVarsUsers;
}

function set-listZendeskUsers_InvokeWebRequestVars() {
	New-Variable -Name WebReqURI_listZendeskUsers -Value "$WebReq_SrvEndpoint`listZendeskUsers" -Scope 2 -Force;
	set-invokeWebRequestPostVars;
	set-invokeWebRequestContentVars;
}

function set-createZendeskUserIdentity_InvokeWebRequestVars() {
	New-Variable -Name WebReqURI_createZendeskUserIdentity -Value "$WebReq_SrvEndpoint`createZendeskUserIdentity" -Scope 2;
	set-invokeWebRequestPostVars;
	set-invokeWebRequestContentVars;
}

function set-makeZendeskUserIdentityPrimary_InvokeWebRequestVars() {
	New-Variable -Name WebReqURI_makeZendeskUserIdentityPrimary -Value "$WebReq_SrvEndpoint`makeZendeskUserIdentityPrimary" -Scope 2;
	set-invokeWebRequestPutVars;
	set-invokeWebRequestContentVars;
}

	##
	# AD QUERY VARS
	##
							################### | AD SOURCE | ###################
function set-srcAdDistinguishedNameVars() {
	New-Variable -Name ...AdDistinguishedName -Value '' -Scope 2;
	New-Variable -Name ...AdDistinguishedName -Value '' -Scope 2;
}

function set-AdDomainVar() {
<#
 .SYNOPSIS
 	Sets variables that specifies the domain canonicalName.
 .EXAMPLE 
 	set-AdDomainVar;
#>	
	New-Variable -Name ...AdDomain -Value '' -Scope 2;
	New-Variable -Name ...AdDomain -Value '' -Scope 2;
}

################### | COMPANIES / ORGANIZATIONS | ################### 				
#### ...
function set-...Ad_MainOuQueries_Full() {
    # For finding Company OU, first level from AD root
	New-Variable -Name ...OUs_Full -Value { Get-ADOrganizationalUnit -Filter ' -not l -eq "NoZendeskOrg" -and Name -notlike "*OLD" ' -Properties Description -SearchScope OneLevel | Where-Object { $_.Description -match '^\d{8}' } | Select-Object @{Name="external_id";Expression={$_.Description}},Name,DistinguishedName } -Scope 2;
	
	# For getting OU's from which users should be [created] or [updated]
	New-Variable -Name ...WhitelistedOUs_Full -Value { Get-ADOrganizationalUnit -Filter ' st -eq "DoCreateZendeskUsers" -or Name -like "*OLD" ' -Properties description | Select-Object @{Name="external_id";Expression={$_.Description}},Name,DistinguishedName } -Scope 2;	
}

function set-...Ad_SubOuQueries_Full($ou) {
<#
 .SYNOPSIS
 	Sets variable that gathers sub-organizational-units on ... AD. 
 .EXAMPLE 
 	set-...Ad_SubOuQueries_Full $ou;
#>
	# For finding Company OU, sub-ou's, relative to company main ou.
	New-Variable -Name ...subOUs -Value { param($ou) Get-ADOrganizationalUnit -Filter ' -not l -eq "NoZendeskOrg" ' -SearchBase $($ou.Value.DistinguishedName) -SearchScope 1 -Properties Description | Where-Object { $_.Description -match '^\d{8}' } | Select-Object @{Name='external_id';Expression={$_.Description}},Name,DistinguishedName } -Scope 2 -Force;	
}

function set-...AdOuQueries_Incremental($lastSync_dateTime) {
<#
 .SYNOPSIS
 	Sets variable that gathers organizational-units on ... AD that has been modified since the $lastSync_dateTime provided. 
 .EXAMPLE 
 	set-...AdOuQueries_Incremental $lastSync_dateTime;
#>
	# OU's [MODIFIED] since last incremental sync
	New-Variable -Name ...OUs_Modified -Value { param($lastSync_dateTime) Get-ADOrganizationalUnit -Filter { whenChanged -gt $lastSync_dateTime -and -not l -eq "NoZendeskOrg" -and Name -notlike "*OLD" } -Properties Description,whenChanged -SearchScope OneLevel | Where-Object { $_.Description -match '^\d{8}' } | Select-Object @{Name='external_id';Expression={$_.Description}},Name,DistinguishedName,whenChanged } -Scope 2 -Force;
}

function set-...Ad_SubOuQueries_Incremental($ou, $lastSync_dateTime) {
<#
 .SYNOPSIS
 	Sets variable that gathers a sub organizational-unit on ... AD that has been modified since the $lastSync_dateTime provided. 
 .EXAMPLE
 	set-...Ad_SubOuQueries_Incremental $ou $lastSync_dateTime;
#>	
	# subOU's [MODIFIED] since last incremental sync 
	New-Variable -Name ...subOUs -Value { param($ou,$lastSync_dateTime) Get-ADOrganizationalUnit -Filter { whenChanged -gt $lastSync_dateTime -and -not l -eq "NoZendeskOrg" } -SearchBase $($ou.Value.DistinguishedName) -SearchScope 1 -Properties Description,whenChanged | where-object { $_.Description -match '^\d{8}' } | Select-Object @{Name='external_id';Expression={$_.Description}},Name,DistinguishedName,whenChanged } -Scope 2 -Force;	
}

#### ...
function set-...AdOuQueries_OU_Full() {
	# Full sync --> get all OU's on ... matching the filter 
	New-Variable -Name ...OUs_Full -Value { Get-ADOrganizationalUnit -SearchBase $...AdSearchBase -Properties Description -filter ' Description -like "K*" -or Description -like "C5*" ' | Select-Object @{Name="external_id";Expression={$_.Description}},Name,DistinguishedName } -Scope 2 -Force;
}

function set-...AdOuQueries_OU_Incremental($lastSync_dateTime) {
	# OU's [MODIFIED] since last incremental sync
	New-Variable -Name ...OUs_Modified -Value { param($lastSync_dateTime) Get-ADOrganizationalUnit -SearchBase $...AdSearchBase -Properties Description,whenChanged -Filter { whenChanged -gt $lastSync_dateTime -and (Description -like "K*" -or Description -like "C5*") } | Select-Object @{Name='external_id';Expression={$_.Description}},Name,DistinguishedName,whenChanged } -Scope 2 -Force;
}

#### IN COMMON
function set-SpecificCompSync_OuQuery($SpecificCompSyncDistinguishedName) {
<#
 .SYNOPSIS
 	Sets variable that defines the variable to invoke when executing for a specific company.
 .EXAMPLE 
 	set-SpecificCompSync_OuQuery $SpecificCompSyncDistinguishedName;
#>	
	$scriptBlockData = " Get-ADOrganizationalUnit -Id $SpecificCompSyncDistinguishedName -Properties Description | Select-Object @{Name='external_id';Expression={`$_.Description}},Name,DistinguishedName "
	$SpecificCompOuVariableValue = [scriptblock]::Create($scriptBlockData); 
	
	New-Variable -Name SpecificCompOu -Value $SpecificCompOuVariableValue -Scope 2 -Force;
}

							################### | USERS | ###################
function set-...AdOuQueries_Users_Incremental($lastSync_dateTime) {
<#
 .SYNOPSIS
 	Sets variables that is invoked when querying organizational-units for users.
 .EXAMPLE 
 	set-...AdOuQueries_Users_Incremental $lastSync_dateTime
#>		
	# Users [CREATED] since last incremental sync
	New-Variable -Name ...Users_Created -Value { param($lastSync_dateTime) Get-ADUser -SearchBase $...AdSearchBase -Properties mail,PrimaryGroup,whenCreated,memberOf -Filter { Enabled -eq "True" -and whenCreated -gt $lastSync_dateTime } | Select-object distinguishedName,name,@{Name="email";Expression={$_.mail}},whenCreated,PrimaryGroup,memberOf,@{Name="external_id";Expression={$_.SID.ToString()}} } -Scope 2 -Force;	

	# Users [MODIFIED] since last incremental sync
	New-Variable -Name ...Users_Modified -Value { param($lastSync_dateTime) Get-ADUser -SearchBase $...AdSearchBase -Properties mail,PrimaryGroup,whenChanged,whenCreated,memberOf -Filter { Enabled -eq "True" -and whenChanged -gt $lastSync_dateTime } | Select-object distinguishedName,name,@{Name="email";Expression={$_.mail}},whenChanged,whenCreated,PrimaryGroup,memberOf,@{Name="external_id";Expression={$_.SID.ToString()}} } -Scope 2 -Force;
}

function set-...AdOuQueries_Users_Full() {
	# For finding active users
	New-Variable -Name ...Users_HashBased_Full -Value { param($ou) Get-ADUser -SearchBase $ou.Value.DistinguishedName -Properties mail,mobile -Filter ' Enabled -eq "True" ' } -Scope 2;
	
	# For finding active users
	New-Variable -Name ...Users_ArrayBased_Full -Value { param($ou) Get-ADUser -SearchBase $ou.DistinguishedName -Properties mail,mobile -Filter ' Enabled -eq "True" ' } -Scope 2;
}

function set-...AdOuQueries_Users_Incremental($lastSync_dateTime) {
<#
 .SYNOPSIS
 	Sets variables that is invoked when querying organizational-units for users.
	Uses 'primaryGroupId -ne 513' in the -Filter parameter on Get-AdUser. This to avoid getting system users, health mailboxes and 
	that kind of user. Id 513 is always the 'Domain Users' group. On the ... environment it is a rule of thumb that no regular customer users
	can be a member of 'Domain Users'.
 .EXAMPLE 
 	set-...AdOuQueries_Users_Incremental $lastSync_dateTime
#>	
	# Users [CREATED] since last incremental sync
	New-Variable -Name ...Users_Created -Value { param($lastSync_dateTime) Get-ADUser -Properties mail,mobile,PrimaryGroup,primaryGroupId,whenCreated,memberOf,department -Filter { Enabled -eq "True" -and whenCreated -gt $lastSync_dateTime -and primaryGroupId -ne 513 } | Select-object distinguishedName,name,@{Name='email';Expression={$_.mail}},mobile,whenCreated,PrimaryGroup,memberOf,@{Name='external_id';Expression={$_.ObjectGUID.ToString()}},department } -Scope 2 -force;

	# Users [MODIFIED] since last incremental sync
	New-Variable -Name ...Users_Modified -Value { param($lastSync_dateTime) Get-ADUser -Properties mail,mobile,PrimaryGroup,primaryGroupId,whenChanged,whenCreated,memberOf,department -Filter { Enabled -eq "True" -and whenChanged -gt $lastSync_dateTime -and primaryGroupId -ne 513 } | Select-object distinguishedName,name,@{Name='email';Expression={$_.mail}},mobile,whenChanged,whenCreated,PrimaryGroup,memberOf,@{Name='external_id';Expression={$_.ObjectGUID.ToString()}},department } -Scope 2 -force;	
}

function set-...AdOuQueries_Users_Full() {
	New-Variable -Name ...Users_HashBased_Full -Value { param($ou) Get-ADUser -SearchBase $ou.Value.DistinguishedName -SearchScope 1 -Properties mail,mobile,department -Filter ' Enabled -eq "True" ' } -Scope 2;
    
	New-Variable -Name ...Users_ArrayBased_Full -Value { param($ou) Get-ADUser -SearchBase $ou.DistinguishedName -SearchScope 1 -Properties mail,mobile,department -Filter ' Enabled -eq "True" ' } -Scope 2;
}

	##
	# SQL VARS BEING SET
	##
		# Used in the determineCompanyTypeTagIt module.
function set-SQLSrvVars() {
	New-Variable -Name SQLSrv -Value "" -Scope 2;
	New-Variable -Name SQLDB -Value "" -Scope 2;
	New-Variable -Name SQLUser -Value '' -Scope 2;
	New-Variable -Name SQLPass -Value '' -Scope 2;
	New-Variable -Name SQLQuery_timeout -Value 5 -Scope 2; # In sec.
	New-Variable -Name SQLQueryExecutingHost -Value "" -Scope 2; # To be kind, so that SQL DBAdmins can determine the invoker of this query/where it is runing from
}

		# Used in the determineCompanyTypeTagIt module.
function set-SQLQueryVars($OuDescription) { 		 
	New-Variable -Name query_determineNavAppCustomerType -Value " exec zendeskIntegration_Get_Company_Type_SP '$($OuDescription)' " -Scope 2 -Force;
	New-Variable -Name query_determineNavUserPrimaryPhone -Value " exec zendeskIntegration_Get_Company_PrimaryPhone_SP '$($OuDescription)' " -Scope 2 -Force;
}

	##
	# E-MAIL VARS BEING SET
	##
function set-MailVars() {
<#
  .DESCRIPTION
	Sets e-mail related variables centrally. 
  .EXAMPLE
	set-MailVars;
#>
	New-Variable -Name mailTo -Value "" -Scope 2;
	New-Variable -Name mailFrom -Value "Zendesk Sync Debug <ZendeskSynchornizerDebug@>" -Scope 2; 
	New-Variable -Name mailServer -Value "MAIL SERVER PLACEHOLDER" -Scope 2;
}

	##
	# VARIOUS VARS BEING SET
	##
function set-syncDataFilePathVar() {
	New-Variable -Name syncDataFilePath -Value "$PSScriptRoot\..\data\syncData.xml" -Scope 2;
}	

function set-regularExpressionVars() {
	New-Variable -Name C5OClassicOuDescriptionRegEx -Value $...ClassicC5ORegEx -Scope 2;		
}

# Used in the determineCompanyTypeTagIt module.
function set-TagNameVars() {
	#### - Zendesk tag names ... - ####
	New-Variable -Name ...Crm -Value "MSCRM" -Scope 2;
	New-Variable -Name ...Full -Value "..." -Scope 2;
	New-Variable -Name ...Mail -Value "Exchange" -Scope 2;
	
	#### - Zendesk tag names ... - ####
	New-Variable -Name C5OClassic -Value "C5O_Classic" -Scope 2;
}

# Used in the determineCompanyTypeTagIt module.
function set-TaggingObjectMemberVars() {
	#### - Define add-member ScriptBlock to be invoked for the different tags - ####
	New-Variable -Name addTagsAsOuObjectMemberHashBased -Value { param($tags, $ou) Add-Member -InputObject $ou.Value -MemberType NoteProperty -Name "tags" -Value $tags -TypeName "zendeskOrgField" } -Scope 2 -Force;
	New-Variable -Name addTagsAsOuObjectMemberArrayBased -Value { param($tags, $ou) Add-Member -InputObject $ou -MemberType NoteProperty -Name "tags" -Value $tags -TypeName "zendeskOrgField" } -Scope 2 -Force;
}

#### [PRIVATE FUNCTIONS] ####
function set-invokeWebRequestPostVars() {
    New-Variable -Name WebReqMethod_POST -Value "Post" -Scope 3 -Force;
}

function set-invokeWebRequestPutVars() {
	New-Variable -Name WebReqMethod_PUT -Value "Put" -Scope 3 -Force;
}

function set-invokeWebRequestGetVars() {
	New-Variable -Name WebReqMethod_GET -Value "Get" -Scope 3;
}

function set-invokeWebRequestContentVars() {
	New-Variable -Name WebReqContent -Value "application/json" -Scope 3 -Force;		
}

function set-invokeWebRequestContentVarsUsers() {
	New-Variable -Name WebReqContentUsers -Value "application/json; charset=utf-8" -Scope 3 -Force;		
}

# Export specific modules/functions outside this script in order to keep certain members private.
Export-ModuleMember -Function set-getZendeskOrganization_InvokeWebRequestVars, set-createZendeskOrg_InvokeWebRequestVars, set-updateZendeskOrg_InvokeWebRequestVars,`
set-...Ad_MainOuQueries_Full, set-...AdOuQueries_Incremental, set-...AdOuQueries_Users_Incremental, set-...AdOuQueries_Users_Incremental, set-...AdOuQueries_Users_Full,`
set-createZendeskUsers_InvokeWebRequestVars, set-...AdOuQueries_Users_Full, set-srcAdDistinguishedNameVars, set-getZendeskUser_InvokeWebRequestVars,`
set-AdDomainVar, set-regularExpressionVars, set-...AdOuQueries_OU_Incremental, set-...AdOuQueries_OU_Full, set-listZendeskUsers_InvokeWebRequestVars,`
set-SQLSrvVars, set-TagNameVars, set-TaggingObjectMemberVars, set-syncDataFilePathVar, set-updateZendeskUsers_InvokeWebRequestVars, set-...Ad_SubOuQueries_Full,`
set-...Ad_SubOuQueries_Incremental, set-SQLQueryVars, set-WebReqSrvEndpointVar, set-SpecificCompSync_OuQuery, set-MailVars, set-createZendeskUserIdentity_InvokeWebRequestVars,`
set-makeZendeskUserIdentityPrimary_InvokeWebRequestVars