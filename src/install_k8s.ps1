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

# Set default value for k8s version, if it not set
if ($config.k8s_version -eq $null) {
    $config.k8s_version = "v1.11.9"
}

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

if ($config.ssh_keygen_enable)
{
    Write-Host "Generate ssh key pair"
    ssh-keygen -t rsa -b 2048
}

# Get ssh
if (-not ([string]::IsNullOrEmpty($config.ssh_path))) 
{
    $sshPath = $config.ssh_path;
}
else 
{
    $sshPath = "$HOME\.ssh\id_rsa.pub";
}

$ssh = Get-Content -Path $sshPath
$ssh = $ssh -replace "`t|`n|`r",""
$resources.k8s_ssh_rsa_public_key = $ssh

# Create k8s cluster with all necessary groups
Write-Host "Creating k8s cluster with all necessary groups and networks..."

Build-EnvTemplate -InputPath "$($path)/../templates/k8s_deploy.json" -OutputPath "$($path)/../temp/k8s_deploy.json" -Params1 $config -Params2 $resources
Build-EnvTemplate -InputPath "$($path)/../templates/k8s_params.json" -OutputPath "$($path)/../temp/k8s_params.json" -Params1 $config -Params2 $resources

$out = az group deployment create --name $config.k8s_deployment_group_name --resource-group $config.az_resource_group `
--template-file "$($path)/../temp/k8s_deploy.json" `
--parameters "$($path)/../temp/k8s_params.json" | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

if ($out -eq $null) {
    Write-Host "Can't deploy AKS."
    return
} else {
    if ($LastExitCode -eq 0) {
        Write-Host "AKS deployment '$($out.name)' has been successfully deployed."
    }
}

Write-Host "Adding AKS cluster context to ~/.kube/config..."
Try {
    $res = az aks get-credentials --resource-group $config.az_resource_group --name $config.k8s_name
    if ( $null -eq $res) { throw $error.Exception }
    else { Write-Host $res }
}
Catch
{
    Write-Host "-----------------------------------------------"
    Write-Host "If You see this message, please, open your kube config file $HOME\.kube\config and remove cluster and context with name: $($config.k8s_name)"
    Read-Host "After that press ENTER to continue..."

    Write-Host "Get kubernetes credentials"

    az aks get-credentials --resource-group $config.az_resource_group --name $config.k8s_name
}

# Write resources
$resources.env_type = "aks"
$resources.az_k8s_rg = "MC_$($config.az_resource_group)_$($config.k8s_name)_$($config.az_region)"

$out = az vm list -g $resources.az_k8s_rg | Out-String | ConvertFrom-Json | ConvertObjectToHashtable
$resources.az_k8s_vm_names = @()
foreach($vm in $out) {
    $resources.az_k8s_vm_names += $vm.name
}

Write-EnvResources -Path $ConfigPath -Resources $resources