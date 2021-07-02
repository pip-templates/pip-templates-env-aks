#!/usr/bin/env pwsh

param
(
    [Alias("Config")]
    [Parameter(Mandatory=$true, Position=0)]
    [string] $ConfigPath,

    [Parameter(Mandatory=$false, Position=1)]
    [string] $ConfigPrefix = "environment",

    [Alias("Resources")]
    [Parameter(Mandatory=$false, Position=2)]
    [string] $ResourcePath,

    [Parameter(Mandatory=$false, Position=3)]
    [string] $ResourcePrefix,

    [Parameter(Mandatory=$false, Position=4)]
    [string] $AzurePrefix = "azure"
)

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

# Set azure subscription and login if needed
try {
    az account set -s $(Get-EnvMapValue -Map $config -Key "$AzurePrefix.subscription")
    
    if ($lastExitCode -eq 1) {
        throw "Cann't set account subscription"
    }
}
catch {
    # Make interactive az login
    az login

    az account set -s $(Get-EnvMapValue -Map $config -Key "$AzurePrefix.subscription")
}

# Delete all resources and deployment
$resourceGroup = Get-EnvMapValue -Map $config -Key "$AzurePrefix.resource_group"
$k8sName = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.name"
Write-Host "Deleting AKS..."
az aks delete -n $k8sName -g $resourceGroup -y
if ($LastExitCode -eq 0) {
    Write-Host "AKS '$k8sName' deleted."
}

Write-Host "Deleting k8s virtual network..."
az network vnet delete -g $resourceGroup -n $(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.vnet_name")
if ($LastExitCode -eq 0) {
    Write-Host "VNET '$(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.vnet_name")' deleted."
}

Write-Host "Deleting deployment..."
az group deployment delete -n $(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.deployment_group_name") -g $resourceGroup
if ($LastExitCode -eq 0) {
    Write-Host "Deployment '$(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.deployment_group_name")' deleted."
}
