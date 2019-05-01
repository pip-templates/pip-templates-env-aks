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

Write-Host "Creating peering connections..."

$out = az network vnet peering create -g $config.az_resource_group -n mgmtToAKS --vnet-name $config.mgmt_win_vm_vnet_name `
    --remote-vnet $config.k8s_vnet_name --allow-vnet-access

if ($out -ne $null) {
    Write-Host "Created peering connection from mgmt station to azure k8s cluster."
}

$out = az network vnet peering create -g $config.az_resource_group -n AKSToMgmt --vnet-name $config.k8s_vnet_name `
    --remote-vnet $config.mgmt_win_vm_vnet_name --allow-vnet-access

if ($out -ne $null) {
    Write-Host "Created perring connection from azure k8s cluster to mgmt station."
}
