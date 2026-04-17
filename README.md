# Hyper-V Automation

PowerShell scripts for automating Hyper-V VM lifecycle: provisioning, snapshots, replication, and reporting. Compatible with Windows Server 2019/2022 Hyper-V.

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/New-HyperVVM.ps1` | Create a new VM from template/VHDX |
| `scripts/Invoke-VMSnapshot.ps1` | Create and manage VM checkpoints |
| `scripts/Get-VMReport.ps1` | Inventory report: CPU, RAM, disk, state |
| `scripts/Set-VMResourceLimits.ps1` | Apply CPU/RAM limits to VMs |
| `scripts/Start-VMBulk.ps1` | Start/stop VMs in a controlled sequence |

## Quick Start

```powershell
# Enable Hyper-V (requires reboot)
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart

# Create a new VM
.\scripts\New-HyperVVM.ps1 `
    -VMName "SRV-WEB-01" `
    -TemplatePath "D:\Templates\WS2022.vhdx" `
    -CPUCount 4 `
    -MemoryGB 8 `
    -SwitchName "Production"

# Generate VM inventory report
.\scripts\Get-VMReport.ps1 | Export-Csv C:\Reports\vm-inventory.csv
```
