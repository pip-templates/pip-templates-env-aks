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
if (![System.Convert]::ToBoolean($(az group exists -n $config.couchbase_az_resource_group))) {
    Write-Host "Resource group with name '$($config.couchbase_az_resource_group)' could not be found. Creating new resource group..."
    $out = az group create --name $config.couchbase_az_resource_group `
    --location $config.couchbase_location | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

    if ($out -eq $null) {
        Write-Host "Can't create resource group '$($config.couchbase_az_resource_group)'"
        return
    } else {
        Write-Host "Resource group '$($config.couchbase_az_resource_group)' created."
    }
} else {
    Write-Host "Using existing resource group '$($config.couchbase_az_resource_group)'"
}

# Creating couchbase server using azure templates
Write-Host "Starting deployment..."

Build-EnvTemplate -InputPath "$($path)/../templates/couchbase_params.json" `
-OutputPath "$($path)/../temp/couchbase_params.json" -Params1 $config -Params2 $resources

$out = az group deployment create --name $config.couchbase_az_deployment `
--resource-group $config.couchbase_az_resource_group `
--template-file "$($path)/../templates/couchbase_deploy.json" `
--parameters "$($path)/../temp/couchbase_params.json" | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

if ($out -eq $null) {
    Write-Host "Can't create couchbase deployment."
    return
} else {
    if ($LastExitCode -eq 0) {
        Write-Host "Deployment '$($out.name)' has been successfully deployed."
    }
}

$resources.couchbase_server_url = $out.properties.outputs.serverAdminURL['value']
$resources.couchbase_sync_gw_url = $out.properties.outputs.syncGatewayAdminURL['value']

# Write resources
Write-EnvResources -Path $ConfigPath -Resources $resources
