#!/usr/bin/env pwsh

param
(
    [Alias("c", "Path")]
    [Parameter(Mandatory=$false, Position=0)]
    [string] $ConfigPath
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

# Set azure subscription and login if needed
try {
    az account set -s $config.az_subscription
    
    if ($lastExitCode -eq 1) {
        throw "Cann't set account subscription"
    }
}
catch {
    # Make interactive az login
    az login

    az account set -s $config.az_subscription
}

# Create resource group if not exists
if (![System.Convert]::ToBoolean($(az group exists -n $config.az_resource_group))) {
    Write-Host "Resource group with name '$($config.az_resource_group)' could not be found. Creating new resource group..."
    $out = az group create --name $config.az_resource_group `
    --location $config.az_region | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

    if ($out -eq $null) {
        Write-Host "Can't create resource group '$($config.az_resource_group)'"
        return
    } else {
        Write-Host "Resource group '$($config.az_resource_group)' created."
    }
} else {
    Write-Host "Using existing resource group '$($config.az_resource_group)'."
}

# Create management windows virtual machine
Write-Host "Creating management windows virtual machine..."

Build-EnvTemplate -InputPath "$($path)/../templates/mgmt_vm_windows_params.json" `
-OutputPath "$($path)/../temp/mgmt_vm_windows_params.json" -Params1 $config -Params2 $resources

$out = az group deployment create --name $config.mgmt_win_vm_deployment_name `
--resource-group $config.az_resource_group `
--template-file "$($path)/../templates/mgmt_vm_windows_deploy.json" `
--parameters "$($path)/../temp/mgmt_vm_windows_params.json" | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

if ($out -eq $null) {
    Write-Host "Can't deploy mgmt VM."
    return
} else {
    if ($LastExitCode -eq 0) {
        Write-Host "VM deployment '$($out.name)' has been successfully deployed."
    }
}

$out = az network public-ip show -g $config.az_resource_group `
-n $config.mgmt_win_vm_pub_ip_name | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

$resources.mgmt_pub_ip_address = $out.ipAddress

# Write resources
Write-EnvResources -Path $ConfigPath -Resources $resources
