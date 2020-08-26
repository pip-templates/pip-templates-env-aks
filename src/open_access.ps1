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

$k8sRG = $resources.az_k8s_rg
$k8sNICs = az network nic list -g $k8sRG | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

# Open ssh port on vms
$k8sNSG = az network nsg list -g $k8sRG | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

Write-Host "Opening ssh port (22) on '$($k8sNSG.name)'..."
$out = az network nsg rule create -g $k8sRG `
    --nsg-name "$($k8sNSG.name)" `
    --name "ssh" `
    --priority 100 `
    --destination-port-ranges 22 

if ($out -ne $null) {
    Write-Host "SSH access to '$($k8sNSG.name)' opened."
}

# Create and assign public ips to k8s NICs
$k8sNodesPublicIps = @()
foreach ($nic in $k8sNICs) {
    Write-Host "Creating and assigning public ip to '$($nic.name)'..."
    # Create public ips to access k8s nodes
    $publicIpName = "$($nic.name)-public-ip"
    #create the public IP
    $out = az network public-ip create -g $k8sRG -n $publicIpName
    #modify the ipconfig by adding the public IP address
    $out = az network nic ip-config update -g $k8sRG --nic-name $nic.name --name ipconfig1 --public-ip-address $publicIpName
    #find out what the allocated public IP address is
    $out = az network public-ip show -g $k8sRG -n $publicIpName `
         | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

    $k8sNodesPublicIps += $out.ipAddress
}

Write-Host "SSH access to all k8s nodes opened."

# Write resources
$resources.k8s_nodes = $k8sNodesPublicIps

Write-EnvResources -Path $ConfigPath -Resources $resources