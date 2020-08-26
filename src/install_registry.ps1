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

# Create azure container registry
Write-Host "Creating container registry..."

Build-EnvTemplate -InputPath "$($path)/../templates/container_registry_params.json" `
-OutputPath "$($path)/../temp/container_registry_params.json" -Params1 $config -Params2 $resources

$out = az group deployment create --name $config.container_registry_deployment_name `
--resource-group $config.az_resource_group `
--template-file "$($path)/../templates/container_registry_deploy.json" `
--parameters "$($path)/../temp/container_registry_params.json" | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

if ($out -eq $null) {
    Write-Host "Can't create container registry."
    return
} else {
    if ($LastExitCode -eq 0) {
        Write-Host "ACR deployment '$($out.name)' has been successfully deployed."

        Write-Host "Recieving acr credentials..."
        $out = az acr credential show --resource-group $config.az_resource_group `
            --name $config.container_registry_name | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

        $resources.container_registry_passwords = $out.passwords[0]
        $resources.container_registry_server = "$($config.container_registry_name).azurecr.io"
    }
}

# Login to new private docker registry
#docker login -u $config.container_registry_name -p "$($resources.container_registry_passwords[0].value)" $resources.container_registry_server

# Write resources
Write-EnvResources -Path $ConfigPath -Resources $resources
