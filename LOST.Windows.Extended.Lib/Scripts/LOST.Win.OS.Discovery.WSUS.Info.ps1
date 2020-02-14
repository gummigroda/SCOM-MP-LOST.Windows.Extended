param($sourceId,$managedEntityId,$computerName,$MGMTName)

function Write-Log([string]$Message) {
	$printDate = (get-date).ToString("yyyy-MM-dd HH:mm:ss.fff")
	$script:traceLog += ("{0} | {1}" -f $printDate, $Message)
	Write-Output ("{0} | {1}" -f $printDate, $Message)
}

try {
	# Set stuff
	[string]$scriptName = $MyInvocation.MyCommand.Name
	[string]$scriptVersion = 'v1.04'
	[int]$evtID = 1337
	$script:traceLog = @()
	[int]$EventType = 4 # type, 1=Error, 2=Warning, 4=Information

	# Pretty hash...
	$AuOpts = @{1 = 'Automatic Updates DISABLED';2 = 'Notify of download and installation';3 = 'Download and notify';4 = 'Download and schedule'}
	$AUDays = @{0='Every Day';1='Sunday';2='Monday';3='Tuesday';4='Wednesday';5='Thursday';6='Friday';7='Saturday'}
	
	Write-Log -Message ("ScriptVersion: [{0}], Running as: [{1}], ManagementGroup: [{2}]" -f $scriptVersion, (whoami), $MGMTName)
	Write-Log -Message ("Start discovery of 'Windows WSUS Settings' with SourceID: [{0}] ManagedID: [{1}] Computername: [{2}]" -f $sourceId, $ManagedEntityId, $computerName)
	
	# Create MOM Script API and Discoverydata
	Write-Log -Message "Creating MOM Object..."
	$api = new-object -comObject 'MOM.ScriptAPI'
	Write-Log -Message "Creating DiscoveryDataObject..."
	$discoveryData = $api.CreateDiscoveryData(0, $SourceId, $ManagedEntityId)

	try{
		# Getting stuff from REG..
		Write-Log -Message "Getting settnings from registry..."
		$WsusSettings = Get-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -ErrorAction Stop
		$AUSettings = Get-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -ErrorAction Stop

		# Set stuff
		[bool]$WSUSTargetGroupEnabled = [bool]$WsusSettings.TargetGroupEnabled
		[string]$WSUSAUOptions = $AuOpts[$AUSettings.AUOptions]
		[bool]$WSUSAUEnabled = ![bool]$AUSettings.NoAutoUpdate
		[bool]$WSUSUseWUServer = [bool]$AUSettings.UseWUServer
		[string]$WSUSInstallDay = $AUDays[$AUSettings.ScheduledInstallDay]
		[string]$WSUSInstallTime = ("{0}{1}" -f $AUSettings.ScheduledInstallTime, ":00")
		[bool]$WSUSRebootLoggedOnsers = [bool]$AUSettings.NoAutoRebootWithLoggedOnUsers

		Write-Log -Message ("WSUSTargetGroupEnabled = {0} WSUSAUOptions = {1}" -f $WSUSTargetGroupEnabled, $WSUSAUOptions)
		Write-Log -Message ("WSUSAUEnabled = {0} WSUSUseWUServer = {1}" -f $WSUSAUEnabled, $WSUSUseWUServer)
		Write-Log -Message ("WSUSInstallDay = {0} WSUSInstallTime = {1}" -f $WSUSInstallDay, $WSUSInstallTime)
		Write-Log -Message ("WSUSRebootLoggedOnUsers = {0}" -f $WSUSRebootLoggedOnsers)
	}
	catch{
		# Set stuff
		[bool]$WSUSTargetGroupEnabled = $false
		[string]$WSUSAUOptions = '-'
		[bool]$WSUSAUEnabled = $false
		[bool]$WSUSUseWUServer = $false
		[string]$WSUSInstallDay = '-'
		[string]$WSUSInstallTime = '-'
		[bool]$WSUSRebootLoggedOnsers = $false
	}
	finally{
		# Add instance
		Write-Log -Message "Creating instance..."
		$instance = $discoveryData.CreateClassInstance("$MPElement[Name='LOST.Windows.OperatingSystem']$")
		$instance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
		$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/WSUSTargetGroupEnabled$", $WSUSTargetGroupEnabled)
		$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/WSUSAUOptions$", $WSUSAUOptions)
		$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/WSUSAUEnabled$", $WSUSAUEnabled)
		$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/WSUSUseWUServer$", $WSUSUseWUServer)
		$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/WSUSInstallDay$", $WSUSInstallDay)
		$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/WSUSInstallTime$", $WSUSInstallTime)
		$instance.AddProperty("$MPElement[Name='LOST.Windows.OperatingSystem']/WSUSRebootLoggedOnUsers$", $WSUSRebootLoggedOnsers)
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
	Write-Log -Message ("Discovery of 'Windows WSUS Settings' is finished.")
	$api.LogScriptEvent($scriptName, $evtID, $EventType, "`n$($Script:TraceLog | Out-String)")
}