Function Get-ComputerInfo {
    Try {
        $ComputerName = $env:COMPUTERNAME

        $ComputerInfo = Get-Ciminstance Win32_ComputerSystem
        $BIOSInfo = Get-CimInstance Win32_BIOS

        $CompReport = [PSCustomObject]@{
             ComputerName = $ComputerName
             CurrentUser = $ComputerInfo.UserName
             Manufacturer = $ComputerInfo.Manufacturer
             Model = $ComputerInfo.Model
             SerialNumber = $BIOSInfo.SerialNumber 
            }

        Return $CompReport
        }
    Catch { 
        Write-Host $_.Exception.message
        }
}

function Get-OperatingSystem {
    Try{
        $OSInfo = Get-CimInstance Win32_OperatingSystem
        $UpTime = New-TimeSpan -Start $OSInfo.LastBootUpTime -End(Get-Date)

        $OSReport = [PSCustomObject]@{
            WindowsVersion = $OSInfo.Version
            BuildNumber = $OSInfo.BuildNumber
            InstallDate = $OSInfo.InstallDate
            LastBootTime = $OSInfo.LastBootUpTime
            SystemUptime = $UpTime
        }
    return $OSReport
    }
    Catch {
        Write-Host $_.Exception.message
    }
}

Function Get-DiskInformation {
    Param (
        [Parameter(Mandatory=$true)]
        [String]$DLetter
    )
    Try {
        $Volume = Get-Volume | Where-Object DriveLetter -eq $DLetter
        
        If (($Volume.SizeRemaining / $Volume.size) -le .10)
            {$Health = "Critical"}

        ElseIf (($Volume.SizeRemaining / $Volume.size) -le .20)
            {$Health = "Warning"}

        Else {$Health = "Healthy"}

        $VolumeReport = [PSCustomObject]@{
            Drive = $Volume.DriveLetter
            SizeGB = "{0:N2}" -f ($Volume.Size/1GB)
            FreeSpaceGB = ("{0:N2}" -f ($Volume.SizeRemaining/1GB)) 
            FreeSpacePercentage = "{0:P2}" -f ($Volume.SizeRemaining / $Volume.size)
            Health = $Health
        }
        Return $VolumeReport
    }
    Catch{
        Write-Host $_.Exception.message
    }
}

Function Get-MemoryInformation {
    Try {
        $OSInfo = Get-CimInstance Win32_OperatingSystem

        $MemoryReport = [PSCustomObject] @{
            TotalRamGB = "{0:N2}" -f ($OSInfo.TotalVisibleMemorySize/1MB)
            FreeRamGB = "{0:N2}" -f ($OSInfo.FreePhysicalMemory/1MB)
            UsedRamGB = "{0:N2}" -f (($OSInfo.TotalVisibleMemorySize - $OSInfo.FreePhysicalMemory)/ 1MB)
            UsedRamPercentage = "{0:P2}" -f (($OSInfo.TotalvisibleMemorySize - $OSInfo.FreePhysicalMemory) / $OSInfo.TotalVisibleMemorySize )
            }
    Return $MemoryReport
    }
    Catch{
        Write-Host $_.Exception.message
    }   
}

Function Get-NetworkInformation {
    Try{
        $Adapter = Get-NetAdapter | Where-Object Name -EQ "Wi-Fi"
        $IP = Get-NetIPAddress -AddressFamily IPv4 | Where-Object InterfaceAlias -EQ "Wi-Fi"
        $Gateway = Get-NetRoute -AddressFamily IPv4 | Where-Object DestinationPrefix -EQ 0.0.0.0/0
        $DNS = Get-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -AddressFamily IPv4

        $NetworkReport = [PSCustomObject]@{
            Adapter = $Adapter.Name
            IPAddress = $IP.IPAddress
            Gateway = $Gateway.NextHop
            DNSServer = $DNS.ServerAddresses
            MacAddress = $Adapter.MacAddress
            Status = $Adapter.Status
            }
            Return $NetworkReport
        }
    Catch { 
        Write-Host $_.Exception.message
    }
}

Function Get-CPUInformation {

    Try{ 
        $CPU=Get-CimInstance Win32_Processor

        $CPUReport = [PSCustomObject]@{
            CPUName = $CPU.Name
            Cores = $CPU.NumberOfCores
            LogicalProcessors = $CPU.NumberOfLogicalProcessors
            CurrentLoad = $CPU.LoadPercentage
        }
        Return $CPUReport
    }
    Catch {
        Write-Host $_.Exception.Message
    }        
}

Function Get-ServiceSummary {
    Try{
        $RunningServices = Get-Service | Where-Object Status -eq "Running"
        $Stopped = Get-Service | Where-Object Status -eq "Stopped"
        $AutoStopped = Get-Service | Where-Object {$_.Status -eq "Stopped" -and $_.StartType -eq "Automatic"}

        If ($AutoStopped.Count -gt 10)
            {$Health = "Critical"}
        
        ElseIf ($AutoStopped.Count -ge 1)
            {$Health = "Warning"}
        
        Else {$Health = "Healthy"}

        $ServiceReport = [PSCustomObject]@{
            RunningServices = $RunningServices.Count
            StoppedServices = $Stopped.count 
            AutomaticStopped = $AutoStopped.count
            ServiceHealth = $Health
        }
        Return $ServiceReport
    }
    Catch {
        Write-Host $_.Exception.Message
    }
}

Function Get-SystemAudit {
    Try {

        # Gather information from all audit functions
        $Computer = Get-ComputerInfo
        $OS = Get-OperatingSystem
        $Disk = Get-DiskInformation -DLetter "C"
        $Memory = Get-MemoryInformation
        $Network = Get-NetworkInformation
        $CPU = Get-CPUInformation
        $Services = Get-ServiceSummary

        # Determine overall system health
        If (
            $Disk.Health -eq "Critical" -or
            $Services.ServiceHealth -eq "Critical"
        ) {
            $OverallHealth = "Critical"
        }

        ElseIf (
            $Disk.Health -eq "Warning" -or
            $Services.ServiceHealth -eq "Warning"
        ) {
            $OverallHealth = "Warning"
        }

        Else {
            $OverallHealth = "Healthy"
        }

        # Create final audit report
        $AuditReport = [PSCustomObject]@{

            # Computer Information
            ComputerName = $Computer.ComputerName
            CurrentUser = $Computer.CurrentUser
            Manufacturer = $Computer.Manufacturer
            Model = $Computer.Model
            SerialNumber = $Computer.SerialNumber

            # Operating System
            WindowsVersion = $OS.WindowsVersion
            BuildNumber = $OS.BuildNumber
            InstallDate = $OS.InstallDate
            LastBootTime = $OS.LastBootTime
            SystemUptime = $OS.SystemUptime

            # CPU
            CPUName = $CPU.CPUName
            Cores = $CPU.Cores
            LogicalProcessors = $CPU.LogicalProcessors
            CurrentLoad = $CPU.CurrentLoad

            # Memory
            TotalRamGB = $Memory.TotalRamGB
            FreeRamGB = $Memory.FreeRamGB
            UsedRamGB = $Memory.UsedRamGB
            UsedRamPercentage = $Memory.UsedRamPercentage

            # Disk
            Drive = $Disk.Drive
            SizeGB = $Disk.SizeGB
            FreeSpaceGB = $Disk.FreeSpaceGB
            FreeSpacePercentage = $Disk.FreeSpacePercentage
            DiskHealth = $Disk.Health

            # Network
            Adapter = $Network.Adapter
            IPAddress = $Network.IPAddress
            Gateway = $Network.Gateway
            DNSServer = ($Network.DNSServer -join ", ")
            MacAddress = $Network.MacAddress
            NetworkStatus = $Network.Status

            # Services
            RunningServices = $Services.RunningServices
            StoppedServices = $Services.StoppedServices
            AutomaticStopped = $Services.AutomaticStopped
            ServiceHealth = $Services.ServiceHealth

            # Overall Health
            OverallHealth = $OverallHealth
        }

        Return $AuditReport
    }

    Catch {
        Write-Host $_.Exception.Message
    }
}
