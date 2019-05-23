param($sourceId,$managedEntityId,$computerName)

function Write-Log([string]$Message) {
	$printDate = (get-date -F s)
	$script:traceLog += ("{0} | {1}" -f $printDate, $Message)
}

try {
	# Set stuff
	[string]$scriptName = $MyInvocation.MyCommand.Name
	[string]$scriptVersion = 'v1.01'
	[int]$evtID = 1337
	[string[]]$script:traceLog = @()
	# type, 1=Error, 2=Warning, 4=Information
	[int]$EventType = 4
	
	# Other
	[int]$cores = 0
	[int]$physicalProcessors = 0
	[int]$logicalProcessors = 0
	[bool]$htActive = $false
	[string]$SMBIOSTAG = ''
	[string]$serialNumber = ''

	Write-Log -Message ("ScriptVersion: [{0}], Running as: [{1}]" -f $scriptVersion, (whoami))
	Write-Log -Message ("Start discovery of SystemInfo with SourceID: [{0}] ManagedID: [{1}] Computername: [{2}]" -f $sourceId, $ManagedEntityId, $computerName)

	# Create MOM Script API and Discoverydata
	Write-Log -Message "Creating MOM Object..."
	$api = new-object -comObject 'MOM.ScriptAPI'
	Write-Log -Message "Creating DiscoveryDataObject..."
	$discoveryData = $api.CreateDiscoveryData(0, $SourceId, $ManagedEntityId)

	# GET AssetTag
	$SMBIOSTAG = (Get-WmiObject Win32_SystemEnclosure).SMBIOSAssetTag.Trim()
	$SerialNumber = (Get-WmiObject win32_bios).serialnumber.Trim()
	
	if ([int](Get-WmiObject Win32_OperatingSystem).version.Split('.')[0] -ge 6){
		# Run on Win2k8 servers only
		$cpudata = Get-WmiObject -class win32_processor -Property "numberOfCores","NumberOfLogicalProcessors"
	
		if ($cpudata.count -gt 0){
			foreach ($cpu in $cpudata){
				$cores += $cpu.numberOfCores
				$logicalProcessors += $cpu.NumberOfLogicalProcessors
			}
			$physicalProcessors = $cpudata.Count
			
		}
		else{
			$cores = $cpudata.numberOfCores
			$logicalProcessors = $cpudata.NumberOfLogicalProcessors
			$physicalProcessors = 1
		}
	
		if ($logicalProcessors -gt $cores){$htActive = $true}
		
		Write-Log -Message ("SystemInfo: CPUCores = {0}`nLogicalProcessors = {1}`nPhysical Processors = {2}`nHyperThreading Active = {3}`nSystem Serial Number = {4}`nSystem AssetTag = {5}" -f $cores, $logicalProcessors, $logicalProcessors, $htActive, $serialNumber, $SMBIOSTAG)
	
		# Add instance
		$instance = $discoveryData.CreateClassInstance("$MPElement[Name='LOST.Windows.Computer']$")
		$instance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
		$instance.AddProperty("$MPElement[Name='LOST.Windows.Computer']/SystemSerial$", $serialNumber)
		$instance.AddProperty("$MPElement[Name='LOST.Windows.Computer']/SMBIOSAssetTag$", $SMBIOSTAG)
		$instance.AddProperty("$MPElement[Name='LOST.Windows.Computer']/CPUCores$", $cores)
		$instance.AddProperty("$MPElement[Name='LOST.Windows.Computer']/CPUHTStatus$", $htActive)
		$discoveryData.AddInstance($instance)
	}
	else {
		#Running on Win2k3 or lower...
		Write-Log -Message ("SystemInfo: System Serial Number = {0}`nSystem AssetTag = {1}" -f $serialNumber, $SMBIOSTAG)
	
		# Add instance
		$instance = $discoveryData.CreateClassInstance("$MPElement[Name='LOST.Windows.Computer']$")
		$instance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
		$instance.AddProperty("$MPElement[Name='LOST.Windows.Computer']/SystemSerial$", $serialNumber)
		$instance.AddProperty("$MPElement[Name='LOST.Windows.Computer']/SMBIOSAssetTag$", $SMBIOSTAG)
		$discoveryData.AddInstance($instance)
	}
}
catch {
	Write-Log -Message ("Error!`n $_ `n")
	$EventType = 1
}
finally {
	# type, 1=Error, 2=Warning, 4=Information
	$discoveryData
	Write-Log ("Discovery of 'System Info' is finished.")
	$api.LogScriptEvent($scriptName, $evtID, $EventType, "`n$($script:traceLog | Out-String)")
}