# LOST.Windows.Extended

A collection of MP's including new classes, discoveries and monitors regarding the Windows Computer Class and the Windows Operating System Class.

## LOST.Windows.Extended.Lib (Management Pack)

### Classes

* **LOST.Windows.Computer**  
Based of *'Microsoft.Windows.Computer'* class with added properties regarding misc hardware. Like serial, BIOS version, HyperThreading, cpu-cores etc...

* **LOST.Windows.OperatingSystem**  
Based of *'Microsoft.Windows.OperatingSystem'* class with added properties regarding WSUS/WindowsUpdate settings and status.  
The class does NOT include clusters, but both *'Microsoft.Windows.Client.OperatingSystem'* and *'Microsoft.Windows.Server.OperatingSystem'* witch makes it good for targeting.

---

### Discoveries

* **LOST.Windows.OS.Server.WSUSInfo.Registry.Discovery** & **LOST.Windows.OS.Client.WSUSInfo.Registry.Discovery**  
Targeted at Client and Server OS and gets the following properties:  
  * WSUS Server
  * WSUS Reporting Server
  * WSUS Target Group

* **LOST.Windows.OS.Server.WSUSInfo.Script.Discovery** & **LOST.Windows.OS.Client.WSUSInfo.Script.Discovery**  
Targeted at Client and Server OS and gets the following properties:  
  * WSUS Target Group Enabled
  * WSUS Automatic Update Options
  * Windows Update Enabled
  * Use WSUS Server
  * WSUS Install day
  * WSUS Install time
  * WSUS Reboot if logged on users

* **LOST.Windows.OS.Server.WU.Script.Discovery** & **LOST.Windows.OS.Client.WU.Script.Discovery**
Targeted at Client and Server OS and gets the following properties:  
  * Windows Update TotalU pdates
  * Windows Update Critical Updates
  * Windows Update Important Updates
  * Windows Update Other Updates
  * Uptime in Weeks

* **LOST.Windows.Computer.SysInfo.Registry.Discovery**  
Targeted at Windows Computer and gets the following properties:  
  * System Manufacturer
  * System ProductName
  * BIOS Version
  * BIOS Release Date
  * BaseBoard Product
  * BaseBoard Version

* **LOST.Windows.Computer.SysInfo.PS.Discovery**  
Targeted at Windows Computer and gets the following properties:  
  * System Serial Number
  * CPU Cores
  * SMBIOS Asset Tag
  * CPU HyperThreading Status

---

### Task

## LOST.Windows.Extended.Monitoring (Management Pack)

### Monitors

* **LOST.Windows.OperatingSystem.Server.PendingReboot.Monitor**  
Alerts if a pending reboot is active.
  * Target: *LOST.Windows.OperatingSystem*

* **LOST.Windows.OperatingSystem.Uptime.Monitor**  
Alerts if the OperatingSystem has been running more than the specified threshold. Defaults to 45 days, can be changed by an override.
  * Target: *LOST.Windows.OperatingSystem*

### Rules

* **LOST.Windows.OperatingSystem.RestartedComputer.Rule**  
Alerts when a computer has been restarted, by EventID 6005 in the 'System' Eventlog.
  * Target: *LOST.Windows.OperatingSystem*

---

## Install

TODO:

* Download and import.