#Requires -RunAsAdministrator
#Requires -Module Hyper-V
<#
.SYNOPSIS
    Create a new Hyper-V VM from a template VHDX (differencing disk).
.PARAMETER VMName
    Name of the new VM.
.PARAMETER TemplatePath
    Path to the parent VHDX template.
.PARAMETER VMPath
    Where to store VM files. Default: default Hyper-V path.
.PARAMETER CPUCount
    Number of virtual processors. Default: 2
.PARAMETER MemoryGB
    RAM in GB (static). Default: 4
.PARAMETER SwitchName
    Virtual switch name. Default: 'Default Switch'
.PARAMETER Generation
    VM generation (1 or 2). Default: 2
.EXAMPLE
    .\New-HyperVVM.ps1 -VMName "SRV-WEB-01" -TemplatePath "D:\Templates\WS2022.vhdx" -MemoryGB 8 -CPUCount 4
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string] $VMName,
    [Parameter(Mandatory)][string] $TemplatePath,
    [string] $VMPath      = (Get-VMHost).VirtualMachinePath,
    [int]    $CPUCount    = 2,
    [int]    $MemoryGB    = 4,
    [string] $SwitchName  = 'Default Switch',
    [int]    $Generation  = 2,
    [int]    $DataDiskGB  = 0
)

if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    Write-Error "VM '$VMName' already exists."
    exit 1
}

if (-not (Test-Path $TemplatePath)) {
    Write-Error "Template not found: $TemplatePath"
    exit 1
}

$vmDir    = Join-Path $VMPath $VMName
$vhdDir   = Join-Path $vmDir 'Virtual Hard Disks'
$vhdPath  = Join-Path $vhdDir "$VMName-OS.vhdx"
$memBytes = $MemoryGB * 1GB

New-Item -ItemType Directory -Path $vhdDir -Force | Out-Null

Write-Host "Creating differencing disk from template..." -ForegroundColor Cyan
if ($PSCmdlet.ShouldProcess($VMName, 'Create VM')) {
    New-VHD -Path $vhdPath -ParentPath $TemplatePath -Differencing | Out-Null

    $vmParams = @{
        Name               = $VMName
        Path               = $vmDir
        MemoryStartupBytes = $memBytes
        VHDPath            = $vhdPath
        SwitchName         = $SwitchName
        Generation         = $Generation
    }
    $vm = New-VM @vmParams

    # CPU
    Set-VM -VM $vm -ProcessorCount $CPUCount
    # Enable dynamic memory
    Set-VMMemory -VM $vm -DynamicMemoryEnabled $true `
        -MinimumBytes ($memBytes / 2) `
        -MaximumBytes ($memBytes * 2) `
        -StartupBytes $memBytes

    # Secure boot (Gen 2)
    if ($Generation -eq 2) {
        Set-VMFirmware -VM $vm -SecureBootTemplate 'MicrosoftWindows'
    }

    # Optional data disk
    if ($DataDiskGB -gt 0) {
        $dataVhd = Join-Path $vhdDir "$VMName-Data.vhdx"
        New-VHD -Path $dataVhd -SizeBytes ($DataDiskGB * 1GB) -Dynamic | Out-Null
        Add-VMHardDiskDrive -VM $vm -Path $dataVhd
        Write-Host "Data disk added: $DataDiskGB GB" -ForegroundColor Green
    }

    # Checkpoints — production type (no RAM state)
    Set-VM -VM $vm -CheckpointType Production

    Write-Host "VM '$VMName' created successfully" -ForegroundColor Green
    Write-Host "  CPU: $CPUCount vCPU | RAM: $MemoryGB GB | Switch: $SwitchName"
    Write-Host ""
    Write-Host "Start the VM with:"
    Write-Host "  Start-VM -Name '$VMName'"
}
