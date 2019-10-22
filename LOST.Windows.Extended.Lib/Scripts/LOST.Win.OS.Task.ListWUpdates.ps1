# Get Pending updates...
param (
	[string]$Debug = "false"
)

function Write-Log {
	param (
		[parameter(Mandatory = $true)]
		[string]$Message,
		[switch]$ToOutput = $false
	)
	$printDate = (get-date -F s)
	$script:traceLog += ("{0} | {1}" -f $printDate, $Message)
	if ($script:dbg -or $ToOutput){
		Write-Output ("{0} | {1}" -f $printDate, $Message)
	}
}

try {
	[string]$scriptName = $MyInvocation.MyCommand.Name
	[string]$scriptVersion = 'v1.03'
	[int]$evtID = 1337
	[string[]]$script:traceLog = @()
	[bool]$script:dbg = $false
	# type, 1=Error, 2=Warning, 4=Information
	[int]$EventType = 4
	[datetime]$StartTime = Get-Date

	# Debug?
	if("yes", "true", "1" -contains $debug){ $script:dbg = $true }

	Write-Log -Message ("ScriptVersion: [{0}], Running as: [{1}]" -f $scriptVersion, (whoami))
	$api = new-object -comObject 'MOM.ScriptAPI'
		
	Write-Log -Message "Getting uptime..."
	if (($PSVersionTable.PSVersion).Major -lt 3){
		$Uptime = ((Get-date) - [datetime][Management.ManagementDateTimeConverter]::ToDateTime((Get-WMIObject win32_operatingsystem).LastBootUpTime)).TotalDays
	}
	else{
		$Uptime = ((Get-date) - [datetime](Get-CimInstance win32_operatingsystem).LastBootUpTime).TotalDays
	}
	
	# Ask WSUS client
	Write-Log -Message ("Creating COM object for WU...")
	$UpdateSession = New-Object -Com Microsoft.Update.Session
	$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
	Write-Log -Message ("Searching for applicable updates...") -ToOutput
	$SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")

	if($SearchResult.Updates.Count -gt 0){
		$Updates = $SearchResult.Updates | select -ExpandProperty Title | Sort | ForEach-Object {"** $_`n"}
		Write-Log -Message ("Updates ({0}) available from WSUS:`n$("-" * 78)`n{1}`n$("-" * 78)" -f $SearchResult.Updates.Count, ($Updates|Out-string)) -ToOutput
	}
	else{
		Write-Log -Message ("No updates available from WSUS") -ToOutput
	}
	Write-Log -Message ("Computer Uptime = {0} day(s)" -f [math]::Round($Uptime,2)) -ToOutput
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