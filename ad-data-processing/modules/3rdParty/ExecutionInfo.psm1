function Get-Execution {
<#
.DESCRIPTION
    This helper function retrieve the PS Callstack properties and sends the output to the caller.
.EXAMPLE
    Get-Execution
#>
    # Get call stack info    
    $CallStack = Get-PSCallStack | Select-Object -Property *;
    
    # Check on number of entries and get the latest
    if( ($CallStack.Count -ne $null) -or (($CallStack.Command -ne '<ScriptBlock>') -and
         ($CallStack.Location -ne '<No file>') -and ($CallStack.ScriptName -ne $Null)) ) {

        # Return             
        $CallStack
    } else {
        Write-Error -Message 'No callstack detected' -Category 'InvalidData';
    }    
}