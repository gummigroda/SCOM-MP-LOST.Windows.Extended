param(
    [int]$DaysThreshold = 70
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
	[string]$scriptVersion = 'v1.01'
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

	# GET UPTIME AND LASTBOOT
	[datetime]$LastBoot = (Get-CimInstance win32_operatingsystem).LastBootUpTime
	$Uptime = (Get-date) - $LastBoot
	[string]$RunTimeString = ("{0} day(s), {1} hour(s), {2} minute(s), {3} second(s)." -f $Uptime.Days, $Uptime.Hours, $Uptime.Minutes, $Uptime.Seconds)

	Write-Log -Message ("Computer started: [{0}]" -f $LastBoot.ToString('s').Replace('T', ' '))
	Write-Log -Message $RunTimeString + " ago."

	if($Uptime.Days -gt $DaysThreshold){
		# Bad stuff
		$Result = 'OverThreshold'
	}
	else{
		# Good stuff
		$Result = 'UnderThreshold'
	}
	[string]$Message = ("The computer has been running for {0}`n" -f $RunTimeString)
	$Message += ("Last boot @ {0}`n" -f $LastBoot.ToString('s').Replace('T', ' '))
	$Message += ("`nThreshold is set to {0} days, and can be changed by an override." -f $DaysThreshold)

    # Adding values
    Write-Log -Message "Adding values to BAG"
	$bag.AddValue('Result',$Result)
	$bag.AddValue('Message', $Message)
	# RETURN
    $bag
	Write-Log -Message ("With message: {0}" -f $Message | Out-String)
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