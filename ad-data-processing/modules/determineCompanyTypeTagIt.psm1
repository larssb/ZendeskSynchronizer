################
# Script preparation
################
# Load PSSnapins, modules x functions
Import-Module -name $PSScriptRoot\zendeskIntegrationConfig -force # Module that configures settings such as vars which is used throughout.

#####################
# FUNCTION - START
#####################
function determineCompanyTypeTagIt() {
<#
.DESCRIPTION
    This module helps determine what type of customer is being processed. Then tags the customer so that the customer shows up in Zendesk with a telling tag.
.PARAMETER ou
    The organizational unit that should be tagged with company type before being transmitted to the Zendesk REST API. 
.PARAMETER srcAD
    The source of the AD making the call to this module.
.EXAMPLE
.NOTES
#>
    
        # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="The organizational unit that should be tagged with company type.")]
        [ValidateNotNullOrEmpty()]
        $ou,
        [Parameter(Mandatory=$true, HelpMessage="Specify which AD is the src")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('','')]
        $srcAD
    )
## 
# Script execution from here on out
##

    # Before trying to set srcAdDistinguishedNameVars check if they haven't already been set
    if( $null -eq (get-variable ...AdDistinguishedName -ErrorAction SilentlyContinue) ) {
        set-srcAdDistinguishedNameVars; # Function in zendeskIntegrationConfig that sets distinguishedname vars for source AD's.
    }
    
    # Before trying to set tagNameVars check if they haven't already been set
    if( $null -eq (get-variable ...Crm -ErrorAction SilentlyContinue) ) {
        set-TagNameVars; # Function in zendeskIntegrationConfig that sets possible tag vars.
    }
    
    # As the incoming ou can both come from a loop over a HASHtable as well as an Array we have to determine which one
    if($null -ne $ou.Value.DistinguishedName) {
        $DistinguishedName = $ou.value.DistinguishedName;
        $OuDescription = $ou.value.external_id;
    } else {
        $DistinguishedName = $ou.DistinguishedName;
        $OuDescription = $ou.external_id;
    }    

    # Check that the src AD defined matches the actual OU object src AD 
    if($srcAD -eq '' -and $DistinguishedName -match $...AdDistinguishedName) {
        # As the incoming ou can both come from a loop over a HASHtable as well as an Array we have to determine which one
        if($null -ne $ou.Value.DistinguishedName) {
            $AdGroups = Get-adgroup -Filter * -SearchBase $ou.Value.DistinguishedName -SearchScope 1;
            $getAcl = { get-acl $ou.value.DistinguishedName };
        } else {
            $AdGroups = Get-adgroup -Filter * -SearchBase $ou.DistinguishedName -SearchScope 1;
            $getAcl = { get-acl $ou.DistinguishedName };
        }

        # Now determine type of customer & set data accordingly    
        if($AdGroups -match 'desktop') {
            # Customer is of type ...
            [array]$tags = $...Full;
            $addTagsAsOuObjectMember = set-addTagsAsOuObjectMemberVar;
            Invoke-Command -ScriptBlock $addTagsAsOuObjectMember -ArgumentList $tags, $ou -NoNewScope;
        } else {
            push-location ad:
            $acl = Invoke-Command -ScriptBlock $getAcl -NoNewScope;
            # Do we have a CRM or Hosted Exchange customer
            if($acl.access.identityreference -match 'MSCRM') {
                # Customer is a CRM customer
                [array]$tags = $...Crm;
                $addTagsAsOuObjectMember = set-addTagsAsOuObjectMemberVar;                
                Invoke-Command -ScriptBlock $addTagsAsOuObjectMember -ArgumentList $tags, $ou -NoNewScope;
            } else {
                # Customer is a Hosted Exchange customer
                [array]$tags = $...Mail;
                $addTagsAsOuObjectMember = set-addTagsAsOuObjectMemberVar;
                Invoke-Command -ScriptBlock $addTagsAsOuObjectMember -ArgumentList $tags, $ou -NoNewScope;
            }
            pop-location;
        }
    } elseif ($srcAD -eq '' -and $DistinguishedName -match $...AdDistinguishedName) {
        # Before trying to set regularExpressionVars check if they haven't already been set
        if( $null -eq (get-variable ...ClassicOuDescriptionRegEx -ErrorAction SilentlyContinue) ) {
            set-regularExpressionVars; # Function in zendesk config module.
        }
        
        # Now determine type of customer & set data accordingly
        if($OuDescription -match ...ClassicOuDescriptionRegEx) {
            # Customer is classic ...
            [array]$tags = ...Classic;
            $addTagsAsOuObjectMember = set-addTagsAsOuObjectMemberVar;            
            Invoke-Command -ScriptBlock $addTagsAsOuObjectMember -ArgumentList $tags, $ou -NoNewScope;
        } else {
            # Customer is Nav app. related customer - Retrieve specific customer type
            if( $null -eq (get-variable SQLSrv -ErrorAction SilentlyContinue) ) {
                set-SQLSrvVars; # Function in zendesk config module.
            }
            # Set SQL query vars. Has to be set everytime.
            set-SQLQueryVars $OuDescription;
            # Query SQL
            try {
                $queryResult = invoke-sqlcmd -serverInstance $SQLSrv -database $SQLDB -username $SQLUser -password $SQLPass -query $query_determineNavAppCustomerType -QueryTimeout $SQLQuery_timeout -HostName $SQLQueryExecutingHost -ErrorVariable $queryResultErrorVariable;
            } catch {
                # Log it with log4net 
                $log4netLogger.error("a) determineCompanyTypeTagIt() | Querying SQL to determine customer type failed with: $_ : The query was: $query_determineNavAppCustomerType");        
                $log4netLogger.error("b) determineCompanyTypeTagIt() | SQL query call Ps error variable: $queryResultErrorVariable");                
            }
            
            # Tag the customer with the type of NAVO customer they are.            
            [array]$tags = $queryResult.CustType;
            $addTagsAsOuObjectMember = set-addTagsAsOuObjectMemberVar;            
            Invoke-Command -ScriptBlock $addTagsAsOuObjectMember -ArgumentList $tags, $ou -NoNewScope;  
        }
    } else {
        # Log it with log4net 
        $log4netLogger.error("determineCompanyTypeTagIt() | AD SRC could not be determined. Customer type not defined!");
        throw "determineCompanyTypeTagIt() | AD SRC could not be determined. Customer type not defined!";        
    }
    
    # Return the tag annotated OU to the main script
    return $ou;
}

##################################
#### PRIVATE helper functions ####
##################################
function set-addTagsAsOuObjectMemberVar() {
# PREPARE FUNCTION
    if( $null -eq (get-variable addTagsAsOuObjectMemberHashBased -ErrorAction SilentlyContinue) ) {
        set-TaggingObjectMemberVars; # Function in zendeskIntegrationConfig that sets possible tag vars.
    }
# RUN      
    # As the incoming ou can both come from a loop over a HASHtable as well as an Array we have to determine which one
    if($null -ne $ou.Value.DistinguishedName) {
        return $addTagsAsOuObjectMemberHashBased;
    } else {
        return $addTagsAsOuObjectMemberArrayBased;
    }
} # End of private function set-addTagsAsOuObjectMemberVar declaration

# Export specific modules/functions outside this script in order to keep certain members private.
Export-ModuleMember -Function determineCompanyTypeTagIt;
###################
# FUNCTION - END
###################