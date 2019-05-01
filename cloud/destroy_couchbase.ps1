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

if ([System.Convert]::ToBoolean($(az group exists -n $config.couchbase_az_resource_group))) {
    Write-Host "Deleting resource group '$($config.couchbase_az_resource_group)' and all resources in it..."
    az group delete --name $config.couchbase_az_resource_group --yes | Out-String | ConvertFrom-Json | ConvertObjectToHashtable
    if ($LastExitCode -eq 0) {
        Write-Host "Resoruce group '$($config.couchbase_az_resource_group)' deleted."
    }
} else {
    Write-Host "Resource group '$($config.couchbase_az_resource_group)' not exists. Nothing to delete."
}