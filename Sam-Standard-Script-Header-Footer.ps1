<# SCRIPT_HEADER #>
#Initializing a $Stopwatch variable to use to measure script execution
$stopwatch =  [system.diagnostics.stopwatch]::StartNew()
#Using Write-Debug and playing with $DebugPreference -> "Continue" will output whatever you put on Write-Debug "Your text/values"
# and "SilentlyContinue" will output nothing on Write-Debug "Your text/values"
$DebugPreference = "Continue"
<# /SCRIPT_HEADER #>

$Message = "Hello world !"
Write-Debug $Message



<# SCRIPT_FOOTER #>
#Stopping StopWatch and report total elapsed time (TotalSeconds, TotalMilliseconds, TotalMinutes, etc...
$stopwatch.Stop()
Write-Host "The script took $StopWatch.Elapsed.TotalSeconds seconds to execute..."
<# /SCRIPT_FOOTER #>