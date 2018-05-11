<#
.SYNOPSIS
Script: Get-CounterStatsPlus
Original Authors: Prashanth, Praveen and Ben Wilkinson for the Convert-HString function.
Modified by : Samuel Drey aka SammyKrosoft to treat the cases where counters have
instances as well as no instances

This script will collect the specific counters value from the multiple target machines/servers 
which will be used to analayze the performance of target servers.

.DESCRIPTION
This script will collect the specific counters value from the multiple target machines/servers 
which will be used to analayze the performance of target servers.

The script will query a defined set of counters that you define there :

$Counter = @"
Processor(_total)\% processor time 
\MSExchange RpcClientAccess\RPC Averaged Latency
\MSExchange RpcClientAccess\RPC Requests
Memory\Available MBytes 
PhysicalDisk(*)\Avg. Disk sec/Transfer 
Network Interface(*)\Bytes Total/sec
\MSExchangeTransport Queues(*)\Submission Queue Length
"@ 

Hint : Chase counters definitions using Powershell ! 
Example:
Get-Counter -ListSet *Memory* | Select -ExpandProperty Counter | ? {$_ -like "*available*"}
Will get you:
\Memory\Available Bytes
\Memory\Available KBytes
\Memory\Available MBytes
Then just copy and paste these on the $Counter = @() definition in the script ... cool eh !




.PARAMETER ServersTXTFile
    This parameter specified the file containing the list of servers to get Perfmon samples from.
    By default it will look for a "servers.txt" file in the same directory as the script.

.PARAMETER NumberOfSamples
    This parameter specifies how many counter samples we need to dump. Default is 5.

    NOTE: each counter query tick depends on many parameters, the most obvious being
    the network between the station where you query the counters from and the serverS 
    that you're querying counters. Each Get-Counter tick is approximately 1 second, so
    -NumberOfSamples 5 will query counters for roughly 5 seconds, 
    and -NumberOfSamples 1000 will query counters for roughly ~17 minutes

.PARAMETER OutputFile
    This parameter specifies the Output file. If not specified, the output file name will be built
    after the script's name, with the date and time appended, and will be stored on the same 
    directory where the script is located.

    NOTE: the size of the file will be approximately 100 bytes per counter value dump. If you get
    1000 counter queries, on 50 performance counters value dump for each query, 
    your target CSV file will have 1000 x 50  x 100 bytes = 5,000,000 bytes ~ 5MBytes

.PARAMETER IncludeFullCounterPath
    This parameter just includes an additional header in the CSV report, which is just the full
    counter path - just in case you wish to include it. Note that it will make the CSV file
    bigger, knowing that 1 ASCII character is 1 byte, if you have a long counter path, like 100
    characters, that will be 100 bytes, times 10,000 counter samples (=10,000 lines in the CSV),
    that is 10,000 x 100 = 1,000,000 bytes, that is almost 1 Megabyte, 100,000 counter samples is
    100 Megabytes ...

    .PARAMETER CheckVersion
    This parameter Checks the script's version.

.INPUTS
    You need to have a file to import from.

.OUTPUTS
    A CSV file which name is constructed with the scripts name appended with the date and time
    of the execution.

.EXAMPLE
.\Get-CounterStatsPlus.ps1
Will execute and dump the counters stats for 5 default samples on a list of servers defined in the C:\Temp\Servers.txt file.
The detault output file will be named after the script's file with the date and time appended, on the same directory where
the script itself is located (Get-CounterStatsPlus.ps1_Date_Time.csv)

.EXAMPLE
.\Get-CounterStatsPlus.ps1 -ServersTXTfile C:\temp\Myservers.txt -NumberOfSamples 20 -OutputFile c:\ExportRequestISsue.csv
Will execute the counters stats for servers list defined in the C:\temp\Myservers.txt, for 20 samples, and store the
results in the output file specified here :C:\ExportRequestIssue.csv

.NOTES
None

.LINK
    https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comment_based_help?view=powershell-6

.LINK
    https://github.com/SammyKrosoft
#>
[CmdLetBinding(DefaultParameterSetName = "NormalRun")]
Param(
    [Parameter(Mandatory = $False, Position = 1, ParameterSetName = "NormalRun")][string]$ServersTXTfile = ".\servers.txt",
    [Parameter(Mandatory = $False, Position = 2, ParameterSetName = "NormalRun")][int]$NumberOfSamples = 5,
    [Parameter(Mandatory = $False, Position = 3, ParameterSetName = "NormalRun")][string]$OutputFile,
    [Parameter(Mandatory = $False, Position = 3, ParameterSetName = "NormalRun")][switch]$IncludeFullCounterPath,
    [Parameter(Mandatory = $false, Position = 4, ParameterSetName = "CheckOnly")][switch]$CheckVersion
)

<# ------- SCRIPT_HEADER (Only Get-Help comments and Param() above this point) ------- #>
#Initializing a $Stopwatch variable to use to measure script execution
$stopwatch = [system.diagnostics.stopwatch]::StartNew()
#Using Write-Debug and playing with $DebugPreference -> "Continue" will output whatever you put on Write-Debug "Your text/values"
# and "SilentlyContinue" will output nothing on Write-Debug "Your text/values"
$DebugPreference = "Continue"
# Set Error Action to your needs
$ErrorActionPreference = "SilentlyContinue"
#Script Version
$ScriptVersion = "1.1"
<# Version changes
v1.1 : added check to not treat blank lines of Servers.TXT files

v1 : first script version
#>
$ScriptName = $MyInvocation.MyCommand.Name
If ($CheckVersion) {Write-Host "SCRIPT NAME     : $ScriptName `nSCRIPT VERSION  : $ScriptVersion";exit}
# Log or report file definition
# NOTE: use $PSScriptRoot in Powershell 3.0 and later or use $scriptPath = split-path -parent $MyInvocation.MyCommand.Definition in Powershell 2.0
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$OutputReport = "$ScriptPath\$($ScriptName)_$(get-date -f yyyy-MM-dd-hh-mm-ss).csv"
# Other Option for Log or report file definition (use one of these)
#$ScriptLog = "$PSScriptRoot\$($ScriptName)-$(Get-Date -Format 'dd-MMMM-yyyy-hh-mm-ss-tt').txt"
<# ---------------------------- /SCRIPT_HEADER ---------------------------- #>
<# -------------------------- DECLARATIONS -------------------------- #>
$Answer = ""
<# /DECLARATIONS #>
<# -------------------------- FUNCTIONS -------------------------- #>
#region Functions region
#Function to have the customized output in CSV format

function Global:Convert-HString {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)] [String]$HString
        )

    <#NOTE: This function is from Ben Wilkinson - https://gallery.technet.microsoft.com/scriptcenter/917c2357-2911-4c79-bd06-ab95714de2d4#>

    Begin 
    {Write-Verbose "Converting Here-String to Array"}
    Process 
    {
        $HString -split "`n" | ForEach-Object {
            $ComputerName = $_.trim()
            if ($ComputerName -notmatch "#")
            {$ComputerName}    
        }
    }#Process
    End 
    {
        # Nothing to do here.
    }
}#Convert-HString

#Performance counters declaration
function Get-CounterStats { 
    param(
        [String[]]$ComputerName = $Env:ComputerName
    ) 

$Counter = @"
Processor(_total)\% processor time 
MSExchange RpcClientAccess\RPC Averaged Latency
MSExchangeIS Store(*)\RPC Average Latency
MSExchange RpcClientAccess\RPC Requests
Memory\Available MBytes 
PhysicalDisk(*)\Avg. Disk sec/Transfer 
Network Interface(*)\Bytes Total/sec
MSExchangeTransport Queues(*)\Submission Queue Length
"@ 

    (Get-Counter -ComputerName $ComputerName -Counter (Convert-HString -HString $Counter)).counterSamples | ForEach-Object {
        $path = $_.path
        $PropertyHash=@{
                WholeCounter = $path;
                ComputerName=($Path -split "\\")[2];
                Instance = $_.InstanceName ;
                Value = [Math]::Round($_.CookedValue,2) 
                DateTime=(Get-Date -format "yyyy-MM-d hh:mm:ss")
        }

        # NOTE: Here we check if the counter is a counter that has instances like process(<process name>)\% Processor Used
        #  or if the counter is just a single instance ocunter like Memory\Available MB.
        # In the case of counters with instances, the PATH 
        If (($path  -split "\\")[3] -eq $null -or ($path -split "\\")[3] -eq "") { 
            $PropertyHash.Add('CounterCategory',$(($path -split "\\")[4]))
            $PropertyHash.Add('CounterName',$(($path  -split "\\")[5]))
        } Else {
            $PropertyHash.Add('CounterCategory',$(($path  -split "\\")[3]))
            $PropertyHash.Add('CounterName',$(($path  -split "\\")[4]))
        }

New-Object PSObject -Property $PropertyHash
    }
}

function IsEmpty($Param){
    If ($Param -eq "All" -or $Param -eq "" -or $Param -eq $Null -or $Param -eq 0) {
        Return $True
    } Else {
        Return $False
    }
}

#endregion functions region
<# /FUNCTIONS #>
<# -------------------------- EXECUTIONS -------------------------- #>
If (IsEmpty $OutputFile){$OutputFile = $OutputReport}

If (!(Test-Path $ServersTXTfile)){
    $MsgErrFileNotFound = "The file $ServersTXTfile is incorrect or doesn't exist ... `nDo you want to gather counters from the local machine ? (Y/N)"
    while ($Answer -ne "Y" -AND $Answer -ne "N") {
        cls
        Write-Host $MsgErrFileNotFound -BackgroundColor Yellow -ForegroundColor Red
        $Answer = Read-host
        If($Answer -eq "N"){Exit} Else {$Servers = $($Env:COMPUTERNAME)}
    }
} Else {
    [string[]]$servers = get-content $ServersTXTFile
    $FinServers = @()
    $Servers | Foreach {
        If ($_ -notmatch "^\s*$"){
            $FinServers += $_.trim()
        }
    $Servers = $FinServers
    }
}

Write-Host "Gathering performance counters for $($Servers -Join ", ")"
Write-Host "That's a total of $($Servers.count) servers"

#Collecting counter information for target servers
#$Expression = ("Get-CounterStats -ComputerName $Servers | Select-Object computerName,datetime,") + $({If ($IncludeFullCounterPath) {"WholeCounter,"}Else{""}}) + ("CounterCategory,CounterName,Instance,Value | Export-Csv -Path $OutputFile -Append -NoTypeInformation")
$Expression = "Get-CounterStats -ComputerName $Servers | Select-Object computerName,datetime,CounterCategory,CounterName,Instance,Value | Export-Csv -Path $OutputFile -Append -NoTypeInformation"
For ($ReRun = 1;$ReRun -le $NumberOfSamples;$ReRun ++){
    Write-Progress -Id 1 -Activity "Gathering $NumberOfSamples counters" -Status "Sample $ReRun of $NumberOfSamples" -PercentComplete ($($rerun/$NumberOfSamples*100))
    invoke-expression $Expression
}

Write-Host "File exported : $outputFile"
notepad $OutputFile

<# /EXECUTIONS #>
<# -------------------------- CLEANUP VARIABLES -------------------------- #>
$OutputFile = $null

<# /CLEANUP VARIABLES#>
<# ---------------------------- SCRIPT_FOOTER ---------------------------- #>
#Stopping StopWatch and report total elapsed time (TotalSeconds, TotalMilliseconds, TotalMinutes, etc...
$stopwatch.Stop()
Write-Host "`n`nThe script took $($StopWatch.Elapsed.TotalSeconds) seconds to execute..."
$StopWatch = $null
<# ---------------- /SCRIPT_FOOTER (NOTHING BEYOND THIS POINT) ----------- #>
