#!/usr/bin/env pwsh

param
(
    [Alias("c", "Path")]
    [Parameter(Mandatory=$true, Position=0)]
    [string] $ConfigPath,
    [Alias("p")]
    [Parameter(Mandatory=$false, Position=1)]
    [string] $Prefix
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

# Delete public ip to close access
foreach ($nic in $k8sNICs) {
    Write-Host "Deleting public ip to '$($nic.name)-public-ip'..."
    $publicIpName = "$($nic.name)-public-ip"
    # !!! Dissociate manualy on portal
    Read-Host "Dissociate public ips on azure portal and press [Enter]"
    #$out = az network nic ip-config update -g $k8sRG --nic-name $nic.name --name ipconfig1 --public-ip-address ""
    $out = az network public-ip delete -g $k8sRG -n $publicIpName
}

# Close ssh access
Write-Host "Closing ssh port (22) on '$($k8sNSG.name)'..."
$out = az network nsg rule delete -g $k8sRG `
    --nsg-name "$($k8sNSG.name)" `
    --name "ssh"

Write-Host "SSH access to '$($k8sNSG.name)' closed."

# Write resources
Write-EnvResources -Path $ConfigPath -Resources $resources
