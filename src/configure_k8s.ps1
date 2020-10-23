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

    Write-Host $out.ipAddress
    $k8sNodesPublicIps += $out.ipAddress
}

## Configure via ansible  
#Prepare hosts file
$ansible_inventory = @("[nodes]")
$i = 0
$sshPrivateKeyPath = $config.ssh_path.Substring(0,$config.ssh_path.Length-4)
foreach ($node in $k8sNodesPublicIps) {
    $ansible_inventory += "node$i ansible_host=$node ansible_ssh_user=$($config.k8s_admin_user) ansible_ssh_private_key_file=$sshPrivateKeyPath"
    $i++
}

Set-Content -Path "$path/../temp/cloud_k8s_ansible_hosts" -Value $ansible_inventory

# Whitelist nodes
Build-EnvTemplate -InputPath "$($path)/../templates/ssh_keyscan_playbook.yml" -OutputPath "$($path)/../temp/ssh_keyscan_playbook.yml" -Params1 $config -Params2 $resources
ansible-playbook -i "$path/../temp/cloud_k8s_ansible_hosts" "$path/../temp/ssh_keyscan_playbook.yml"

# Configure instances for elasticsearch
Build-EnvTemplate -InputPath "$($path)/../templates/elasticsearch_prerequsites_playbook.yml" -OutputPath "$($path)/../temp/elasticsearch_prerequsites_playbook.yml" -Params1 $config -Params2 $resources
ansible-playbook -i "$path/../temp/cloud_k8s_ansible_hosts" "$path/../temp/elasticsearch_prerequsites_playbook.yml"

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
$resources.k8s_inventory = $ansible_inventory

Write-EnvResources -Path $ConfigPath -Resources $resources
