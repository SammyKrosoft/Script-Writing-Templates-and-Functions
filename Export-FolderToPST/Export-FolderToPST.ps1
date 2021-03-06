<#
.SYNOPSIS

    This script wraps around a New-MailboxExportRequest command to export a mailbox to a
    network location (Exchange 2010/2013 require a UNC path with New-MailboxExportRequest)

.DESCRIPTION
PREREQUISITES :

1- the account with which you launch the below export script MUST be a member of a role group
that has the "Mailbox Import Export"  rights. On PCO, that role group is "Mailbox Exports"
NOTE: If such a Role Group does NOT exist, see Sam's blog post on the LINK section below...

2- The UNC path where you export the PST must start with double slashes, and it seems that it works
only when you export on Exchange servers (Exchange Trusted Subsystem account seems to be needed as local admin
of the machine where you export the PST)

.PARAMETER FolderToExport
<FolderName>/*: Use this syntax to denote a personal folder under the folder specified in the SourceRootFolder parameter, for example, "MyProjects" or "MyProjects/FY2010".
#<FolderName>#/*: Use this syntax to denote a well-known folder regardless of the folder's name in another language. For example, #Inbox# denotes the Inbox folder even if the Inbox is localized in Turkish, which is Gelen Kutusu. 

.PARAMETER MailboxToExport
Mailbox name to export from ...

.PARAMETER UNCFilePathToExportThePST
Network path to the target PST ... must be a server where Exchange Trusted Subsystem has read/write permissions.

.PARAMETER ExportRequestName
Export requests must have a name ... 

.EXAMPLE
.\Export-FolderToPST.ps1

Will export the folder that you hard coded on the variable $FolderToExport
from the mailbox that is specified in the variable $MailboxToExport
and it will put it on the UNC path specified in the variable $UNCFilePathToExportThePST
The Request will be able to be retrieved using Get-MailboxExportRequest with the "-Name" parameter
and the name provided in the $ExportRequestName variable.

.EXAMPLE
.\Export-FolderToPST.ps1 -ExportRequestName "MyExportRequest01"

Will create an Export request to dump a mailbox inside a PST file, and the Export request job will be called "MyExportRequest01".
The mailbox it will search in will be the one hard coded in the $MailboxToExport, the UNC Path specified on the $UNCFilePathToExportThePST,
and the folder specified on the $FolderToExport variable.

.LINK
https://blogs.technet.microsoft.com/samdrey/2011/02/16/exchange-2010-rbac-issue-mailbox-import-export-new-mailboximportrequest-and-other-management-role-entries-are-missing-not-available/

#>
[CmdletBinding(DefaultParameterSetName = "NormalRun")]
param(
    [parameter(Mandatory = $false, Position = 1, ParameterSetName = "NormalRun")][string]$FolderToExport = "Archive/April 2018/Inbox/*",
    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = "NormalRun")][string]$MailboxToExport = "Test User 1",
    [Parameter(Mandatory = $false, Position = 3, ParameterSetName = "NormalRun")][string]$UNCFilePathToExportThePST = "\\YourExchangeExportServer\C$\temp\Restored-$(get-date -f yyyy-MM-dd-hh-mm-ss).pst",
    [Parameter(Mandatory = $false, Position = 4, ParameterSetName = "NormalRun")][string]$ExportRequestName = "MyExportRequest",
    [Parameter(Mandatory = $false, Position = 5, ParameterSetName = "CheckVersion")][switch]$CheckVersion
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
$ScriptVersion = "0.5"
<# Version changes
-> v0.5
formatted Parameters with CmdletBinding and added -CheckVersion switch
#>
If ($CheckVersion) {Write-Host "Script Version v$ScriptVersion";exit}
# Log or report file definition
# NOTE: use #PSScriptRoot in Powershell 3.0 and later or use $scriptPath = split-path -parent $MyInvocation.MyCommand.Definition in Powershell 2.0
#$LogOrReportFile1 = "$PSScriptRoot\ReportOrLogFile_$(get-date -f yyyy-MM-dd-hh-mm-ss).csv"
# Other Option for Log or report file definition (use one of these)
#$LogOrReportFile2 = "$PSScriptRoot\PowerShellScriptExecuted-$(Get-Date -Format 'dd-MMMM-yyyy-hh-mm-ss-tt').txt"
<# ---------------------------- /SCRIPT_HEADER ---------------------------- #>

#Removing previous Mailbox Export request that had the same name as the name provided
#Note for the future: we can develop a simple routing that checks for existing $ExportRequestName, and if it exists, exit the script with instruction to specify another name...
Remove-MailboxExportRequest $ExportRequestName
    
#Write-Host "Checking if Exchange can find $MAilboxToExport ..." 
#Note for the future: we can test if the mailbox targetted exists, and if it doesn't, exit the script...
#Get-mailbox $MailboxToExport

Write-Host "Trying to export data from $MailboxToExport and targetting folder $FolderToExport ..."
New-MailboxExportRequest -Name $ExportRequestName -IncludeFolders $FolderToExport -Mailbox $MailboxToExport -Filepath $UNCFilePathToExportThePST

#Getting the status of the newly created Export Request...
Get-MailboxExportRequest -name $ExportRequestName 

<# ---------------------------- SCRIPT_FOOTER ---------------------------- #>
#Stopping StopWatch and report total elapsed time (TotalSeconds, TotalMilliseconds, TotalMinutes, etc...
$stopwatch.Stop()
Write-Host "`n`nThe script took $($StopWatch.Elapsed.TotalSeconds) seconds to execute..."
<# ---------------- /SCRIPT_FOOTER (NOTHING BEYOND THIS POINT) ----------- #>