param($sourceId,$managedEntityId,$computerName,$MGMTName)

function Write-Log([string]$Message) {
	$printDate = (get-date).ToString("yyyy-MM-dd HH:mm:ss.fff")
	$script:traceLog += ("{0} | {1}" -f $printDate, $Message)
	Write-Output ("{0} | {1}" -f $printDate, $Message)
}

try {
	# Set stuff
	[string]$scriptName = 'LOST.Win.OS.Discovery.WU.ps1'
	[string]$scriptVersion = 'v1.06'
	[int]$evtID = 1337
	$script:traceLog = @()
	[int]$EventType = 4 # type, 1=Error, 2=Warning, 4=Information
	# WU
	[string]$totalUpdates = '0, None'
	[int]$critcalUpdates = 0
	[int]$importantUpdates = 0
	[int]$otherUpdates = 0
	
	Write-Log -Message ("ScriptVersion: [{0}], Running as: [{1}], ManagementGroup: [{2}]" -f $scriptVersion, (whoami), $MGMTName)
	Write-Log -Message ("Start discovery of 'Windows Updates' with SourceID: [{0}] ManagedID: [{1}] Computername: [{2}]" -f $sourceId, $ManagedEntityId, $computerName)
	
	# Create MOM Script API and Discoverydata
	Write-Log -Message "Creating MOM Object..."
	$api = new-object -comObject 'MOM.ScriptAPI'
	Write-Log -Message "Creating DiscoveryDataObject..."
	$discoveryData = $api.CreateDiscoveryData(0, $SourceId, $ManagedEntityId)
	
	# Get uptime, if PSVersion < 3 do the old way
	Write-Log -Message "Getting uptime..."
	if (($PSVersionTable.PSVersion).Major -lt 3){
		$Uptime = (Get-date) - [datetime][Management.ManagementDateTimeConverter]::ToDateTime((Get-WMIObject win32_operatingsystem).LastBootUpTime)
	}
	else{
		$Uptime = (Get-date) - [datetime](Get-CimInstance win32_operatingsystem).LastBootUpTime
	}
	[int]$WeekUptime = [math]::floor($Uptime.Totaldays/7) # Round down

	# Ask WSUS client
	Write-Log -Message ("Creating COM object for WU...")
	$UpdateSession = New-Object -Com Microsoft.Update.Session
	$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
	Write-Log -Message ("Searching for applicable updates...")
	$SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")

	if($SearchResult.Updates.Count -gt 0){
		Write-Log -Message ("[{0}] updates found. Parsing result" -f $SearchResult.Updates.Count)
		foreach ($update in $SearchResult.Updates){
			if ($update.MsrcSeverity -eq 'Critical'){
				#"Critical"
				$critcalUpdates ++
			}
			elseif ($update.MsrcSeverity -eq 'Important'){
				#"Important"
				$importantUpdates ++
			}
			else {
				#"Other"
				$otherUpdates ++
			}
		}
		if ($SearchResult.Updates.Count -eq 1){
			# Echo the title
			$totalUpdates = "001, " + $SearchResult.Updates.Item(0).Title
		}
		else{
			# A kind of string sort
			if ($SearchResult.Updates.Count -lt 10) {
				$totalUpdates = "00" + $SearchResult.Updates.Count
			}
			elseif ($SearchResult.Updates.Count -lt 100) {
				$totalUpdates = "0" + $SearchResult.Updates.Count
			}
			else {
				$totalUpdates = $SearchResult.Updates.Count
			}
		}
	}

	Write-Log -Message ("Total updates = $totalUpdates `nCritical Updates = $critcalUpdates `nImportant updates = $importantUpdates `nOther Updates = $otherUpdates")
	# Add instance
	$instance = $discoveryData.CreateClassInstance("$MPElement[Name='LOST.Windows.OperatingSystem']$")
	$instance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
	$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/WUTotalUpdates$", $totalUpdates)
	$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/WUCriticalUpdates$", $critcalUpdates)
	$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/WUImportantUpdates$", $importantUpdates)
	$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/WUOtherUpdates$", $otherUpdates)
	$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/WeekUptime$", $WeekUptime)
	$discoveryData.AddInstance($instance)
}
catch {
	Write-Log -Message ("Error!`n$_ `n")
	$EventType = 1
	
	Write-Log -Message "Trying to add error info and week uptime instance..."
	$api.LogScriptEvent($scriptName, 1338, $EventType, "`nError getting pending updates!`n$($Error[0].Exception.ToString())")
	if ($instance){Remove-Variable instance}
	# Add instance
	$instance = $discoveryData.CreateClassInstance("$MPElement[Name='LOST.Windows.OperatingSystem']$")
	$instance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
	if ($WeekUptime){ $instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/WeekUptime$", $WeekUptime)}
	$discoveryData.AddInstance($instance)
}
finally {
	# type, 1=Error, 2=Warning, 4=Information
	$discoveryData
	Write-Log -Message ("Discovery of 'Windows Updates' is finished.")
	$api.LogScriptEvent($scriptName, $evtID, $EventType, "`n$($Script:TraceLog | Out-String)")
}