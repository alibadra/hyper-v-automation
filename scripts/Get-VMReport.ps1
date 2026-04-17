#Requires -Module Hyper-V
<#
.SYNOPSIS
    Generate a full Hyper-V VM inventory report.
.EXAMPLE
    .\Get-VMReport.ps1
    .\Get-VMReport.ps1 | Export-Csv C:\Reports\vm-inventory.csv -NoTypeInformation
#>

$vms = Get-VM

if (-not $vms) {
    Write-Host "No VMs found on this host." -ForegroundColor Yellow
    return
}

$report = foreach ($vm in $vms) {
    $disks = Get-VMHardDiskDrive -VM $vm | ForEach-Object {
        $vhd = Get-VHD -Path $_.Path -ErrorAction SilentlyContinue
        if ($vhd) { "$([math]::Round($vhd.FileSize/1GB,1))/$([math]::Round($vhd.Size/1GB,0))GB" }
    }

    $nets = Get-VMNetworkAdapter -VM $vm
    $ips  = ($nets.IPAddresses | Where-Object { $_ -match '^\d+\.' }) -join '; '

    [PSCustomObject]@{
        Name          = $vm.Name
        State         = $vm.State
        Generation    = $vm.Generation
        CPUs          = $vm.ProcessorCount
        MemAssigned_GB = [math]::Round($vm.MemoryAssigned / 1GB, 1)
        MemDemand_GB  = [math]::Round($vm.MemoryDemand / 1GB, 1)
        Disks_UsedTotal = $disks -join ' | '
        IPAddresses   = $ips
        Uptime        = if ($vm.Uptime) { $vm.Uptime.ToString('d\.hh\:mm') } else { '-' }
        Checkpoints   = (Get-VMCheckpoint -VM $vm).Count
        ReplicationMode = $vm.ReplicationMode
        CreationTime  = $vm.CreationTime.ToString('yyyy-MM-dd')
    }
}

$report | Format-Table -AutoSize
Write-Host "`nTotal VMs: $($report.Count) | Running: $(($report | Where-Object State -eq 'Running').Count)"
$report
