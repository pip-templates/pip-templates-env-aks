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

Write-Host "Deleting AKS..."
az aks delete -n $config.k8s_name -g $config.az_resource_group -y
if ($LastExitCode -eq 0) {
    Write-Host "AKS '$($config.k8s_name)' deleted."
}

Write-Host "Deleting k8s virtual network..."
az network vnet delete -g $config.az_resource_group -n $config.k8s_vnet_name
if ($LastExitCode -eq 0) {
    Write-Host "VNET '$($config.k8s_vnet_name)' deleted."
}

Write-Host "Deleting deployment..."
az group deployment delete -n $config.k8s_deployment_group_name -g $config.az_resource_group
if ($LastExitCode -eq 0) {
    Write-Host "Deployment '$($config.k8s_deployment_group_name)' deleted."
}
