# TEST NETWORKPORT
param (
	[parameter(Mandatory = $true)]
	[string]$Hostnames,
	[parameter(Mandatory = $true)]
	[int]$NetworkPort
)

function Write-Log {
	param (
		[parameter(Mandatory = $true)]
		[string]$Message,
		[switch]$ToOutput = $false
	)
	$printDate = (get-date -F s)
	$script:traceLog += ("{0} | {1}" -f $printDate, $Message)
	if ($ToOutput){
		Write-Output ("{0} | {1}" -f $printDate, $Message)
	}
}

try {
	[string]$scriptName = 'LOST.Win.Comp.Task.TestNetPort.ps1'
	[string]$scriptVersion = 'v1.02'
	[int]$evtID = 1337
	[string[]]$script:traceLog = @()
	# type, 1=Error, 2=Warning, 4=Information
	[int]$EventType = 4
	[datetime]$StartTime = Get-Date

	Write-Log -Message ("ScriptVersion: [{0}], Running as: [{1}]" -f $scriptVersion, (whoami)) -ToOutput:$false 
	$api = new-object -comObject 'MOM.ScriptAPI'

	# Rinse when more than one host
	[string[]]$hosts = $Hostnames.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries)
	$hosts = $hosts | ForEach-Object{ $_.trim() }

	Write-Log -Message ("Running from $env:COMPUTERNAME") -ToOutput
	$localAdresses = (Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPAddress -ne $null }).ipaddress
	Write-Log -Message ("with local adress: $localAdresses") -ToOutput

	foreach ($HostToTest in $hosts) {
		Write-Log -Message ("-------------- Trying to resolve: [{0}] ----------------" -f $HostToTest) -ToOutput
		try {
			$ips = [System.Net.Dns]::GetHostAddresses($HostToTest)
			Write-Log -Message ("  Resolved to: [$ips]") -ToOutput
		}
		catch {
			Write-Log -Message ("  Can't resolve [{0}], possibly wrong hostname or IP" -f $HostToTest) -ToOutput
			continue
		}
		foreach ($address in $ips) {
			try {
				$TheAddress = $address.IPAddressToString
				Write-Log -Message ("  Trying to connect to [{0}]..." -f $TheAddress) -ToOutput
				$t = New-Object Net.Sockets.TcpClient
				$t.Connect($TheAddress, $NetworkPort)
			}
			catch { }
			if ($t.Connected) {
				$t.Close()
				Write-Log -Message ("  Success! TCP Port [{0}] on address [{1} ({2})] is OPEN" -f $NetworkPort, $TheAddress, $HostToTest) -ToOutput
			}
			else {
				Write-Log -Message ("  Failed! TCP Port [{0}] on address [{1} ({2})] is CLOSED" -f $NetworkPort, $TheAddress, $HostToTest) -ToOutput
			}
		}
	}
}
catch {
	Write-Log -Message ("Error!`n $_ `n") -ToOutput
	$EventType = 1
}
finally {
	# type, 1=Error, 2=Warning, 4=Information
	Write-Log -Message ("-------------------------------------------------------" -f $HostToTest) -ToOutput
	Write-Log ("Task completed in {0} second(s)." -f ((Get-Date) - $StartTime).TotalSeconds)
	$api.LogScriptEvent($scriptName, $evtID, $EventType, "`n$($script:traceLog | Out-String)")
}