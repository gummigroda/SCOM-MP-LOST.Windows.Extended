# GET OS LASTBOOTTIME AND UPTIME

function Write-Log([string]$Message) {
		$printDate = (get-date -F s)
		$script:traceLog += ("{0} | {1}" -f $printDate, $Message)
		Write-Output ("{0} | {1}" -f $printDate, $Message)
}

try{
	[string]$scriptName = 'LOST.Win.Comp.Task.GetUptime.ps1'
	[string]$scriptVersion = 'v1.00'
	[int]$evtID = 1337
	[string[]]$script:traceLog = @()
	# type, 1=Error, 2=Warning, 4=Information
	[int]$EventType = 4
	[datetime]$StartTime = Get-Date

	Write-Log -Message ("ScriptVersion: [{0}], Running as: [{1}]" -f $scriptVersion, (whoami))
	$api = new-object -comObject 'MOM.ScriptAPI'

	# GET UPTIME AND LASTBOOT
	if (($PSVersionTable.PSVersion).Major -lt 3){
		[datetime]$LastBoot = [Management.ManagementDateTimeConverter]::ToDateTime((Get-WMIObject win32_operatingsystem).LastBootUpTime)
	}
	else{
		[datetime]$LastBoot = (Get-CimInstance win32_operatingsystem).LastBootUpTime
	}
	$Uptime = (Get-date) - $LastBoot
	Write-Log -Message ("Computer started: [{0}]" -f $LastBoot.ToString('s').Replace('T', ' '))
	Write-Log -Message ("{0} day(s), {1} hour(s), {2} minute(s), {3} second(s) ago." -f $Uptime.Days, $Uptime.Hours, $Uptime.Minutes, $Uptime.Seconds)
}
catch {
	Write-Log -Message ("Error!`n $_ `n")
	$EventType = 1
}
finally {
	# type, 1=Error, 2=Warning, 4=Information
	Write-Log ("Task completed in {0} second(s)." -f ((Get-Date) - $StartTime).TotalSeconds)
	$api.LogScriptEvent($scriptName, $evtID, $EventType, "`n$($script:traceLog | Out-String)")
}