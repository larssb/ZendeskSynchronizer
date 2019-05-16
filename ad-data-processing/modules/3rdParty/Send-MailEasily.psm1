################
# Script preparation
################

## ! Load PSSnapins, modules x functions

## ! Variables to be used in the script

#####################
# FUNCTION - START
#####################
function Send-MailEasily() {
<#
.SYNOPSIS
    .
.DESCRIPTION
    .
.PARAMETER " Some parameter "
    " SOME DESCRIPTION OF SAID PARAMETER "
.EXAMPLE
    C:\PS> 
    <Description of example>
.NOTES
#>
    # Define parameters
    param(
        [Parameter(Mandatory=$true, HelpMessage="The e-mail to send to.")]
        [ValidateNotNullOrEmpty()]
        $mailTo,
		[Parameter(Mandatory=$true, HelpMessage="The e-mail to send from.")]
        [ValidateNotNullOrEmpty()]
		$mailFrom,
		[Parameter(Mandatory=$true, HelpMessage="The e-mail subject.")]
        [ValidateNotNullOrEmpty()]
		$mailSubject,
		[Parameter(Mandatory=$true, HelpMessage="The e-mail server.")]
        [ValidateNotNullOrEmpty()]
		$mailServer,        		
        [Parameter(Mandatory=$true, HelpMessage="The e-mail body content.")]
        [ValidateNotNullOrEmpty()]		
		$mailBodyContent
    )
##
# Script execution from here on out
##
$mailBody = @"
<!DOCTYPE html>
<html>
	<head>
		<style>
body
{
background-color:#ffffff;
}
p
{
font-family:"Tahoma";
font-size:11px;
margin-top:15px;
margin-bottom:20px;
margin-right:25px;
margin-left:25px;
}

		</style>
	</head>
	<body>
		<p> $mailBodyContent
	</body>
</html>
"@
	
	# Send the mail
	Send-MailMessage -To $mailTo -From $mailFrom -Subject $mailSubject -BodyAsHtml $mailBody -SmtpServer $mailServer -Encoding ([System.Text.Encoding]::UTF8);
}
###################
# FUNCTION - END
###################