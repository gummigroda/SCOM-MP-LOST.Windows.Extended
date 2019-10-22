param($sourceId,$managedEntityId,$computerName)

try {
	function Write-Log([string]$Message) {
		$printDate = (get-date -F s)
		$script:traceLog += ("{0} | {1}" -f $printDate, $Message)
		Write-Output ("{0} | {1}" -f $printDate, $Message)
	}
	
	# Set stuff
	[string]$scriptName = $MyInvocation.MyCommand.Name
	[string]$scriptVersion = 'v1.01'
	[int]$evtID = 1337
	$script:traceLog = @()
	[int]$EventType = 4 # type, 1=Error, 2=Warning, 4=Information

	# Pretty hash...
	$LicReason = [ordered]@{0='Unlicensed';1='Licensed';2='OOB Grace';3='OOT Grace';4='Non-Genuine Grace';5='Notification';6='Extended Grace'}
	
	Write-Log -Message ("ScriptVersion: [{0}], Running as: [{1}]" -f $scriptVersion, (whoami))
	Write-Log -Message ("Start discovery of 'Windows LicenseStatus' with SourceID: [{0}] ManagedID: [{1}] Computername: [{2}]" -f $sourceId, $ManagedEntityId, $computerName)
	
	# Create MOM Script API and Discoverydata
	Write-Log -Message "Creating MOM Object..."
	$api = new-object -comObject 'MOM.ScriptAPI'
	Write-Log -Message "Creating DiscoveryDataObject..."
	$discoveryData = $api.CreateDiscoveryData(0, $SourceId, $ManagedEntityId)

	# Getting stuff from WMI...
	Write-Log -Message "Getting settnings from WMI..."
	# If more than one lic, get the first one...
	$LicStatus = Get-WmiObject SoftwareLicensingProduct | 
				Where-Object {$_.PartialProductKey -and $_.Name -like '*Windows*'} |
				Select -First 1 Name, ApplicationId, @{N='LicenseStatus';E={$LicReason[[int]$_.LicenseStatus]}}
	Write-Log -Message ("License Name = [{0}] ApplicationID = [{1}] License Status = [{2}]" -f $LicStatus.Name, $LicStatus.ApplicationId, $LicStatus.LicenseStatus)

	# Add instance
	Write-Log -Message "Creating instance..."
	$instance = $discoveryData.CreateClassInstance("$MPElement[Name='LOST.Windows.OperatingSystem']$")
	$instance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
	$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/License$", $LicStatus.Name)
	$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/ApplicationID$", $LicStatus.ApplicationId)
	$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/LicenseStatus$", $LicStatus.LicenseStatus)
	$discoveryData.AddInstance($instance)
	Write-Log -Message "Instance added."
}
catch {
	Write-Log -Message ("Error!`n $_ `n")
	$EventType = 1
}
finally {
	# type, 1=Error, 2=Warning, 4=Information
	$discoveryData
	Write-Log -Message ("Discovery of 'Windows LicenseStatus' is finished.")
	$api.LogScriptEvent($scriptName, $evtID, $EventType, "`n$($Script:TraceLog | Out-String)")
}