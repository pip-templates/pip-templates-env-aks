#!/usr/bin/env pwsh

param
(
    [Alias("c", "Config")]
    [Parameter(Mandatory=$true, Position=0)]
    [string] $ConfigPath,

    [Parameter(Mandatory=$false, Position=1)]
    [string] $ConfigPrefix = "k8s",

    [Alias("r", "Resources")]
    [Parameter(Mandatory=$false, Position=2)]
    [string] $ResourcePath,

    [Parameter(Mandatory=$false, Position=3)]
    [string] $ResourcePrefix,

    [Parameter(Mandatory=$false, Position=4)]
    [string] $AzurePrefix = "azure",

    [Parameter(Mandatory=$false, Position=5)]
    [string] $MgmtPrefix = "mgmt"
)

# Stop on error
$ErrorActionPreference = "Stop"

# Load support functions
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }
. "$($path)/../common/include.ps1"
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }

# Set default parameter values
if (($ResourcePath -eq $null) -or ($ResourcePath -eq ""))
{
    $ResourcePath = ConvertTo-EnvResourcePath -ConfigPath $ConfigPath
}
if (($ResourcePrefix -eq $null) -or ($ResourcePrefix -eq "")) 
{ 
    $ResourcePrefix = $ConfigPrefix 
}

# Read config and resources
$config = Read-EnvConfig -ConfigPath $ConfigPath
$resources = Read-EnvResources -ResourcePath $ResourcePath

Write-Host "Creating peering connections..."

$out = az network vnet peering create -g $(Get-EnvMapValue -Map $config -Key "$AzurePrefix.resource_group") `
    -n mgmtToAKS --vnet-name $(Get-EnvMapValue -Map $config -Key "$MgmtPrefix.vnet_name") `
    --remote-vnet $(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.vnet_name") --allow-vnet-access

if ($out -ne $null) {
    Write-Host "Created peering connection from mgmt station to azure k8s cluster."
}

$out = az network vnet peering create -g $(Get-EnvMapValue -Map $config -Key "$AzurePrefix.resource_group") `
    -n AKSToMgmt --vnet-name $(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.vnet_name") `
    --remote-vnet $(Get-EnvMapValue -Map $config -Key "$MgmtPrefix.vnet_name") --allow-vnet-access

if ($out -ne $null) {
    Write-Host "Created perring connection from azure k8s cluster to mgmt station."
}
