################
# Script preparation
################

## ! Load PSSnapins, modules x functions
Import-Module -Name $PSScriptRoot\purifyOuDescription.psm1 -force # Module that returns the debitor num or GUID part of the OU description.

#####################
# FUNCTION - START
#####################
function transformOuToJSON() {
<#
.SYNOPSIS
    Transforms incoming AD organizational unit to Zendesk conforming organization in JSON. 
.DESCRIPTION
    Transforms incoming AD organizational unit to Zendesk conforming organization in JSON.
.PARAMETER ou
    AD organizational unit object. Contains what is to be converted into Zendesk organization data.
.PARAMETER transformType
    With transformType you specify if the JSON you want output is for updating or creating an organization.      
.PARAMETER zendeskOrgID
    Define the Zendesk organization ID of the customer to be updated. This parameter is [DYNAMIC] ! - Only available when 'update' is the 
    defined transformType.      
.EXAMPLE
.NOTES
#>
    
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="Company ou has to be specified.")]
        [ValidateNotNullOrEmpty()]
        $ou,
        [Parameter(Mandatory=$true, HelpMessage="Transform type is to tell the module if JSON is for updating or creating Zendesk org.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('create','update')]
        $transformType,
        [Parameter(Mandatory=$false, HelpMessage="Switch parameter to define that the request comes from ... AD.")]
        [Switch]
        $srcAdIs...
    )
    
    DynamicParam {
        if($transformType -eq 'update') {
            # Configure parameter
            $attributes = new-object System.Management.Automation.ParameterAttribute;
            $attributes.Mandatory = $false;
            $attributes.HelpMessage = "Zendesk Organization ID of the incoming company. Necessary when updating.";
            $ValidateNotNullOrEmpty = New-Object Management.Automation.ValidateNotNullOrEmptyAttribute;
            
            # Define parameter collection
            $attributeCollection = new-object -Type System.Collections.ObjectModel.Collection[System.Attribute];
            $attributeCollection.Add($attributes);
            $attributeCollection.Add($ValidateNotNullOrEmpty);
            
            # Prepare to return & expose the parameter
            $ParameterName = "zendeskOrgID";
            [Type]$ParameterType = "Object";
            $Parameter = New-Object Management.Automation.RuntimeDefinedParameter($ParameterName, $ParameterType, $AttributeCollection);
            if ($psboundparameters.ContainsKey('DefaultValue')) {
                $Parameter.Value = $DefaultValue;
            }
            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary;
            $paramDictionary.Add('zendeskOrgID', $Parameter);
            return $paramDictionary;
        }
    }
##
# Script execution from here on out
##
    Begin {};
    Process {
        # Create hashtables for further definition of JSON
        $JSONouterContainer = @{}; # When updating organization.
        $organization = @{};
        $org = @{};
        
        if($transformType -eq 'create') {
            # transform type is create --> return JSON object to [create] an organization
            $org.name = $ou.Value.Name;
            if($srcAdIs... -eq $true) {
                # Call purifyOuDescription module to get purified version of the OU description data. If we did not purify external ID for C5O Classic customers
                # would look a la: 'K36919270,S0,E0'.
                $purifiedOuDescription = purifyOuDescription -ouDescription $ou.Value.external_id;
                $org.external_id = $purifiedOuDescription;
            } else {
                $org.external_id = $ou.Value.external_id;
            }
            $org.tags = $ou.Value.tags;
        } else {
            # transform type is update --> return JSON object to [update] an organization
            $JSONouterContainer.orgToZendesk = $organization;
            $JSONouterContainer.organizationID = $psboundparameters.zendeskOrgID;
            $org.name = $ou.Value.Name;
        }
    
        # Create a deeper level to match JSON the Zendesk REST API expects when we request it to create an Zendesk organization
        $organization.organization = $org;
    
        # Convert the OU to JSON
        if($transformType -eq 'create') {
            $OUinJSON = ConvertTo-Json -InputObject $organization;        
        } else {
            $OUinJSON = ConvertTo-Json -InputObject $JSONouterContainer;
        }
        return $OUinJSON;
    }; # End of Process statement
    End {};
} # End of function declaration

Export-ModuleMember -Function transformOuToJSON;
###################
# FUNCTION - END
###################