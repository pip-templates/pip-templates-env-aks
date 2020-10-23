#!/usr/bin/env pwsh

param
(
    [Alias("c", "Path")]
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $ConfigPath,
    [Alias("p")]
    [Parameter(Mandatory=$false, Position=1)]
    [string] $Prefix
)

$ErrorActionPreference = "Stop"

# Load support functions
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }
. "$($path)/../lib/include.ps1"
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }

# Read config and resources
$config = Read-EnvConfig -Path $ConfigPath
$resources = Read-EnvResources -Path $ConfigPath

# Define expected values
$e_OS = "Ubuntu 16.04"
$e_maxCpuUsage = 90
$e_minMemMb = 2000

# Prepare hosts file
$ansibleInventory = @("[nodes]")
$i = 0
foreach ($node in $config.nodes_ips) {
    $ansibleInventory += "node$i ansible_host=$node ansible_ssh_user=$($config.username) ansible_ssh_private_key_file=$($config.ssh_private_key_path)"
    $i++
}

Set-Content -Path "$path/../temp/test_ansible_hosts" -Value $ansibleInventory

# Whitelist nodes
Build-EnvTemplate -InputPath "$($path)/../templates/ssh_keyscan_playbook.yml" `
    -OutputPath "$($path)/../temp/ssh_keyscan_playbook.yml" -Params1 $config -Params2 $resources
ansible-playbook -i "$path/../temp/test_ansible_hosts" "$path/../temp/ssh_keyscan_playbook.yml"

if ($LastExitCode -ne 0) {
    Write-Host "Some instances not accessible via ssh. See error message above to get instance ip. Check is port 22 open and instance state is running."
}

Build-EnvTemplate -InputPath "$($path)/../templates/test_info_playbook.yml" `
    -OutputPath "$($path)/../temp/test_info_playbook.yml" -Params1 $config -Params2 $resources
ansible-playbook -i "$path/../temp/test_ansible_hosts" "$path/../temp/test_info_playbook.yml"

$instancesInfo = Import-Csv "$path/../temp/instances.csv"

# Prepare array with nodes
$ansibleInventoryArray = $ansibleInventory.Split("`n")
# remove hosts group name
$ansibleInventoryArray = $ansibleInventoryArray[1..$ansibleInventoryArray.Count]
# cycle through each node
foreach ($i in $ansibleInventoryArray) {
    $line = $i.Split(" ")
    $hostName = $line[0]
    $ip = $line[1].SubString($line[1].IndexOf("=")+1)

    $instanceInfo = $instancesInfo | Where hostname -eq $hostName

    # Check connection
    if ($instanceInfo -eq $null) {
        Write-Host "Host $hostName ($ip) not accessible via ssh - Error (host unreachable, view ansible logs above)`n"
        continue
    }
    Write-Host "Host $($hostName) ($ip) ssh connection - OK"

    # Check OS
    $nodeOS = "$($instanceInfo.os_name) $($instanceInfo.os_version)"
    if ($nodeOS -eq $e_OS) {
        Write-Host "Node OS ($nodeOS) - OK"
    } else {
        Write-Host "Node OS ($nodeOS) not equal no expected ($e_OS) - Error"
    }
    
    # Check CPU usage
    if (($instanceInfo.user_cpu_usage -lt $e_maxCpuUsage) -and `
        ($instanceInfo.system_cpu_usage -lt $e_maxCpuUsage)) {
        Write-Host "CPU usage: user $($instanceInfo.user_cpu_usage) %, system $($instanceInfo.system_cpu_usage) - OK"
    } else {
         Write-Host "CPU usage higher than expected value ($e_maxCpuUsage): user $($instanceInfo.user_cpu_usage) %; system $($instanceInfo.system_cpu_usage) - Error"
    }
    
    # Check memory
    if ([convert]::ToInt32($instanceInfo.mem_total) -ge [convert]::ToInt32($e_minMemMb)) {
        Write-Host "MEM total: $($instanceInfo.mem_total) - OK"
    } else {
        Write-Host "MEM total: $($instanceInfo.mem_total) less then expected minimum $e_minMemMb - Error"
    }
    if ([convert]::ToInt32($instanceInfo.mem_free) -ge [convert]::ToInt32($e_minMemMb)) {
        Write-Host "MEM free: $($instanceInfo.mem_free) - OK"
    } else {
        Write-Host "MEM free: $($instanceInfo.mem_free) less then expected minimum $e_minMemMb - Error"
    }

    # Separate nodes by empty line
    Write-Host ""
}
