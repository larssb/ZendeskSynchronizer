#####################
# FUNCTION - START
#####################
function userToJSON() {
<#
.DESCRIPTION
    - This function prepares an AD user to be converted to JSON. Manipulating its properties to match Zendesk requirements as well
    as company internal requirements.
.PARAMETER adUser
    The AD user object that should be processed.
.EXAMPLE
    $userInJSON = userToJSON -transformType $transformType -adUser $user.value -zendeskAssignedOrgID $zendeskAssignedOrgID -userPrimaryPhone $userPrimaryPhone;
.NOTES
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="Transform type is to tell the module if JSON is for incremental or full Zendesk users sync.")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('create','update','full')]       
        $transformType,
        [Parameter(Mandatory=$true, HelpMessage="AD user object.")]
        [ValidateNotNullOrEmpty()]
        $adUser,
        [Parameter(Mandatory=$false, ParameterSetName="transformType_Create", HelpMessage="The Zendesk organization ID retrieved from Zendesk when the company was created.")]
        [ValidateNotNullOrEmpty()]
        $zendeskAssignedOrgID, 
        [Parameter(Mandatory=$false, ParameterSetName="transformType_Create", HelpMessage="When transformtype is 'create' or 'full'. State the primary phone number of the user.")]
        [AllowNull()]
        [AllowEmptyString()]       
        $userPrimaryPhone                      
    )
##
# Script execution from here on out
##
    # Iterate over the properties on the user object & remove all properties with a value of $null - As the Zendesk REST API does not handle null values in the JSON data
    foreach($property in $adUser.psobject.Properties) { 
        # Clean-up & create user_field properties on the user
        if($null -eq $property.Value -or $property.Name -eq 'DistinguishedName') { 
            $adUser.psobject.Properties.remove($property.name);
        } elseif($property.Name -eq 'mobile') {
            # Create user_fields on the user (These fields are custom created fields in Zendesk)
            $mobile = $property.Value; # first temporarily store the property as we will have to remove it as a direct property on the user
            $adUser.psobject.Properties.remove($property.name); # remove the property from the current level
            $user_fields = @{};
            $user_fields.mobile = @();
            Add-Member -InputObject $adUser -MemberType NoteProperty -Name "user_fields" -Value $user_fields -TypeName "zendeskCustomUserField"; # To be able to assign custom fields to the user
            $adUser.user_fields.mobile += $mobile
        }
    }
    
    # Only add verified, org. id & phone to the user JSON object if we are doing a FULL sync or the user is to be CREATED on Zendesk
    if($transformType -eq 'full' -or $transformType -eq 'create') 
    {
        # Annotate the user with additional information
        Add-Member -InputObject $adUser -MemberType NoteProperty -Name "organization_id" -Value $zendeskAssignedOrgID -TypeName "zendeskUserField"; # To associate the user with their organization/company.
        if($null -ne $userPrimaryPhone) {
            Add-Member -InputObject $adUser -MemberType NoteProperty -Name "phone" -Value $userPrimaryPhone -TypeName "zendeskUserField"; # Set phone on the user.       
        }
    }

    # Verification e-mail from Zendesk will not be sent out. We always do this no matter the transformtype.
    Add-Member -InputObject $adUser -MemberType NoteProperty -Name "verified" -Value $true -TypeName "zendeskUserField"; 
    
    # Return the user object.
    $adUser;   
}

Export-ModuleMember -Function userToJSON;
###################
# FUNCTION - END
###################