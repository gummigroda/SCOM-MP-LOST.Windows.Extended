param(
    [string]$debug = 'false'
)

try{
	function Write-Log([string]$Message) {
		$printDate = (get-date -F s)
		$script:traceLog += ("{0} | {1}" -f $printDate, $Message)
		Write-Output ("{0} | {1}" -f $printDate, $Message)
	}

	# Settings
	[int]$evtID = 1337
	$script:traceLog = @()
	[string]$scriptName = $MyInvocation.MyCommand.Name
	[string]$scriptVersion = 'v1.00'
	[bool]$InError = $false
	[bool]$ScriptDebug = $false
	[int]$EventType = 4

	Write-Log -Message "ScriptVersion: $scriptVersion"

	# Check if to DEBUG
	if (@('true','1',1) -contains $Debug){ [bool]$ScriptDebug = $true }
	if ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\LOST\SCOM\OSUpdate' -Name DebugMonitor -ErrorAction SilentlyContinue).DebugMonitor -eq 1){
		Write-Log -Message "Debug Active."
		$ScriptDebug = $true
	}

	# Create MOM Script API and MOM propertyBag
	$api = new-object -comObject 'MOM.ScriptAPI'
    $bag = $api.CreatePropertyBag()

    #Based on <http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542>
    # Set Defaults
    $result = @{
        CBSRebootPending = $false
        WindowsUpdateRebootRequired = $false
        FileRenamePending = $false
        SCCMRebootPending = $false
    }

    # Check CBS Registry
	Write-Log -Message "Checking CBS Registry."
    $key = Get-ChildItem "HKLM:Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue
    if ($key -ne $null) {
		Write-Log -Message "CBSRebootPending = TRUE"
        $result.CBSRebootPending = $true
    }
   
    # Check Windows Update
	Write-Log -Message "Checking Windows Update."
    $key = Get-Item "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue
    if($key -ne $null) {
		Write-Log -Message "WindowsUpdateRebootRequired = TRUE"
        $result.WindowsUpdateRebootRequired = $true
    }

    # Check PendingFileRenameOperations
	Write-Log -Message "Checking PendingFileRenameOperations"
    $prop = Get-ItemProperty "HKLM:SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    if($prop -ne $null) {
		Write-Log -Message "PendingFileRenameOperations = TRUE"
        #PendingFileRenameOperations is not *must* to reboot?
        $result.FileRenamePending = $true
		$result.FileRenamePendingFiles = $prop.PendingFileRenameOperations
    }
    
    try 
    { 
        Write-Log -Message ("Checking SCCM Client reboot")
		$util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
        $status = $util.DetermineIfRebootPending()
        if(($status -ne $null) -and $status.RebootPending){
			Write-Log -Message "SCCMRebootPending = TRUE"
            $result.SCCMRebootPending = $true
        }
    }
    catch{}
   
    # Create bag
    Write-Log -Message "Adding values to BAG"
    [string]$Description = ''
    if ($result.CBSRebootPending -or $result.WindowsUpdateRebootRequired -or $result.SCCMRebootPending){
        Write-Log -Message "Setting PENDINGREBOOT = YES"
		$bag.AddValue('PENDINGREBOOT', 'YES')
        if ($result.CBSRebootPending) {
            $Description += " - The 'Component-Based Servicing' [1] component require a OperationSystem reboot. `r`n"
        }
        if ($result.WindowsUpdateRebootRequired) {
            $Description += " - The 'Windows Update' component require a OperationSystem reboot. `r`n"
        }
        if ($result.SCCMRebootPending) {
            $Description += " - The 'SCCM Client' component require a OperationSystem reboot. `r`n"
        }
        if ($result.FileRenamePending) {
            $Description += " - The 'PendingFileRenameOperations' component wishes a OperationSystem reboot. `r`n"
			$Description += $result.FileRenamePendingFiles
        }
    }
    else {
        Write-Log -Message "Setting PENDINGREBOOT = NO"
        $bag.AddValue('PENDINGREBOOT', 'NO')
        $Description += "No actions needed."
    }
    # RETURN
	Write-Log -Message "Returning property bag"
    $bag.AddValue('Description', $Description)
    $bag
	Write-Log -Message ("With description: {0}" -f $Description | Out-String)
}
catch {
	Write-Log -Message ("Error!`n $Error[0] `n")
	$InError = $true
	$EventType = 1
}
finally {
	# EventType, 1=Error, 2=Warning, 4=Information
	Write-Log ("Monitor PENDING REBOOT PROBE Script Done!")
	if ($InError -or $ScriptDebug){
		$api.LogScriptEvent($scriptName, $evtID, $EventType, "`n$($Script:TraceLog | Out-String)")
	}
}
