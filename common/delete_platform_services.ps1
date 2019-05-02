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

# Delete mosquitto
kubectl delete -f "$($path)/../templates/k8s_components/mosquitto.yml"

# Delete redis
kubectl delete -f "$($path)/../templates/k8s_components/redis.yml"

# Delete logging
kubectl delete -f "$($path)/../templates/k8s_components/logging.yml"

# Delete metrics
kubectl delete -f "$($path)/../templates/k8s_components/metrics.yml"
