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

# Delete all resources and deployment

Write-Host "Deleting mgmt virtual machine..."
az vm delete -g $config.az_resource_group -n $config.mgmt_win_vm_name -y
if ($LastExitCode -eq 0) {
    Write-Host "VM '$($config.mgmt_win_vm_name)' deleted."
}

Write-Host "Deleting mgmt disk..."
az disk delete -g $config.az_resource_group -n $config.mgmt_win_vm_disk_name -y
if ($LastExitCode -eq 0) {
    Write-Host "Disk '$($config.mgmt_win_vm_disk_name)' deleted."
}

Write-Host "Deleting mgmt network interface..."
az network nic delete -g $config.az_resource_group -n $config.mgmt_win_vm_nic_name
if ($LastExitCode -eq 0) {
    Write-Host "NIC '$($config.mgmt_win_vm_nic_name)' deleted."
}

Write-Host "Deleting mgmt public ip..."
az network public-ip delete -g $config.az_resource_group -n $config.mgmt_win_vm_pub_ip_name
if ($LastExitCode -eq 0) {
    Write-Host "PublicIp '$($config.mgmt_win_vm_pub_ip_name)' deleted."
}

Write-Host "Deleting mgmt network security group..."
az network nsg delete -g $config.az_resource_group -n $config.mgmt_win_vm_nsg_name
if ($LastExitCode -eq 0) {
    Write-Host "NSG '$($config.mgmt_win_vm_nsg_name)' deleted."
}

Write-Host "Deleting mgmt virtual network..."
az network vnet delete -g $config.az_resource_group -n $config.mgmt_win_vm_vnet_name
if ($LastExitCode -eq 0) {
    Write-Host "VNET '$($config.mgmt_win_vm_vnet_name)' deleted."
}

Write-Host "Deleting deployment..."
az group deployment delete -n $config.mgmt_win_vm_deployment_name -g $config.az_resource_group
if ($LastExitCode -eq 0) {
    Write-Host "Deployment '$($config.mgmt_win_vm_deployment_name)' deleted."
}
