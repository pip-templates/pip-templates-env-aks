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

# Install ingress controller (need for client apps)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml
if ($config.env_type -ne "local") {
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/cloud-generic.yaml
}

# Install namespace
kubectl apply -f "$($path)/../templates/k8s_components/namespace.yml"

# Install mosquitto
kubectl apply -f "$($path)/../templates/k8s_components/mosquitto.yml"

# Install redis
kubectl apply -f "$($path)/../templates/k8s_components/redis.yml"

# Install logging
kubectl apply -f "$($path)/../templates/k8s_components/logging.yml"

# Install metrics
kubectl apply -f "$($path)/../templates/k8s_components/metrics.yml"
