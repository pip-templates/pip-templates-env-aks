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
    [string] $AzurePrefix = "azure"
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
Write-Host "Deleting container registry..."
az acr delete -g $resourceGroup -n $(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.name")
if ($LastExitCode -eq 0) {
    Write-Host "ACR '$(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.name")' deleted."
}

Write-Host "Deleting deployment..."
az group deployment delete -g $resourceGroup -n $(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.deployment_name")
if ($LastExitCode -eq 0) {
    Write-Host "Deployment '$(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.deployment_name")' deleted."
}
