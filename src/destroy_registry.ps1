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

Write-Host "Deleting container registry..."
az acr delete -g $config.az_resource_group -n $config.container_registry_name
if ($LastExitCode -eq 0) {
    Write-Host "ACR '$($config.container_registry_name)' deleted."
}

Write-Host "Deleting deployment..."
az group deployment delete -g $config.az_resource_group -n $config.container_registry_deployment_name
if ($LastExitCode -eq 0) {
    Write-Host "Deployment '$($config.container_registry_deployment_name)' deleted."
}
