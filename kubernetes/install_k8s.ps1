#!/usr/bin/env pwsh

param
(
    [Alias("c", "Config")]
    [Parameter(Mandatory=$true, Position=0)]
    [string] $ConfigPath,

    [Parameter(Mandatory=$false, Position=1)]
    [string] $ConfigPrefix = "k8s",

    [Alias("r", "Resources")]
    [Parameter(Mandatory=$false, Position=2)]
    [string] $ResourcePath,

    [Parameter(Mandatory=$false, Position=3)]
    [string] $ResourcePrefix,

    [Parameter(Mandatory=$false, Position=4)]
    [string] $AzurePrefix = "azure"
)

# Stop on error
$ErrorActionPreference = "Stop"

# Load support functions
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }
. "$($path)/../common/include.ps1"
$path = $PSScriptRoot
if ($path -eq "") { $path = "." }

# Set default parameter values
if (($ResourcePath -eq $null) -or ($ResourcePath -eq ""))
{
    $ResourcePath = ConvertTo-EnvResourcePath -ConfigPath $ConfigPath
}
if (($ResourcePrefix -eq $null) -or ($ResourcePrefix -eq "")) 
{ 
    $ResourcePrefix = $ConfigPrefix 
}

# Read config and resources
$config = Read-EnvConfig -ConfigPath $ConfigPath
$resources = Read-EnvResources -ResourcePath $ResourcePath

# Set azure subscription and login if needed
try {
    az account set -s $(Get-EnvMapValue -Map $config -Key "$AzurePrefix.subscription")
    
    if ($lastExitCode -eq 1) {
        throw "Cann't set account subscription"
    }
}
catch {
    # Make interactive az login
    az login

    az account set -s $(Get-EnvMapValue -Map $config -Key "$AzurePrefix.subscription")
}

# Create resource group if not exists
$resourceGroup = Get-EnvMapValue -Map $config -Key "$AzurePrefix.resource_group"
if (![System.Convert]::ToBoolean($(az group exists -n $resourceGroup))) {
    Write-Host "Resource group with name '$resourceGroup' could not be found. Creating new resource group..."
    $out = az group create --name $resourceGroup `
    --location $(Get-EnvMapValue -Map $config -Key "$AzurePrefix.region") | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

    if ($out -eq $null) {
        Write-Host "Can't create resource group '$resourceGroup'"
        return
    } else {
        Write-Host "Resource group '$resourceGroup' created."
    }
} else {
    Write-Host "Using existing resource group '$resourceGroup'."
}

if (Get-EnvMapValue -Map $config -Key "$ConfigPrefix.ssh.keygen_enable")
{
    Write-Host "Generate ssh key pair"
    ssh-keygen -t rsa -b 2048
}

# Get ssh
if (-not ([string]::IsNullOrEmpty(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.ssh.path"))) 
{
    $sshPath = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.ssh.path"
}
else 
{
    $sshPath = "$HOME\.ssh\id_rsa.pub";
}

$ssh = Get-Content -Path $sshPath
$ssh = $ssh -replace "`t|`n|`r",""
Set-EnvMapValue -Map $resources -Key "$ResourcePrefix" -Value @{}
Set-EnvMapValue -Map $resources -Key "$ResourcePrefix.ssh_rsa_public_key" -Value $ssh

# Create k8s cluster with all necessary groups
Write-Host "Creating k8s cluster with all necessary groups and networks..."

$templateParams = @{ 
    az_resource_group = Get-EnvMapValue -Map $config -Key "$AzurePrefix.resource_group"
    az_sp_app_id = Get-EnvMapValue -Map $config -Key "$AzurePrefix.sp_app_id"
    az_sp_password = Get-EnvMapValue -Map $config -Key "$AzurePrefix.sp_password"
    k8s_name = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.name"
    k8s_dns_name_prefix = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.dns_name_prefix"
    k8s_agent_vm_size = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.agent_vm_size"
    k8s_agent_count = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.agent_count"
    k8s_admin_user = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.admin_user"
    k8s_vnet_name = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.vnet_name"
    k8s_vnet_address_cidr = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.vnet_address_cidr"
    k8s_subnet_name = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.subnet_name"
    k8s_subnet_address_cidr = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.subnet_address_cidr"
    k8s_service_cidr = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.service_cidr"
    k8s_dns_service_ip = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.dns_service_ip"
    k8s_docker_bridge_cidr = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.docker_bridge_cidr"
    k8s_ssh_rsa_public_key = Get-EnvMapValue -Map $resources -Key "$ResourcePrefi.ssh_rsa_public_key"
}
Build-EnvTemplate -InputPath "$($path)/templates/k8s_deploy.json" -OutputPath "$($path)/../temp/k8s_deploy.json" -Params1 $templateParams
Build-EnvTemplate -InputPath "$($path)/templates/k8s_params.json" -OutputPath "$($path)/../temp/k8s_params.json" -Params1 $templateParams

$out = az group deployment create --name $(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.deployment_group_name") `
--resource-group $resourceGroup `
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
$k8sName = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.name"
Try {
    $res = az aks get-credentials --resource-group $resourceGroup --name $k8sName
    if ( $null -eq $res) { throw $error.Exception }
    else { Write-Host $res }
}
Catch
{
    Write-Host "-----------------------------------------------"
    Write-Host "If You see this message, please, open your kube config file $HOME\.kube\config and remove cluster and context with name: $($k8sName)"
    Read-Host "After that press ENTER to continue..."

    Write-Host "Get kubernetes credentials"

    az aks get-credentials --resource-group $resourceGroup --name $k8sName
}

# Write resources
$resources.env_type = "aks"
$resources.az_k8s_rg = "MC_$resourceGroup_$($k8sName)_$(Get-EnvMapValue -Map $config -Key "$AzurePrefix.region")"

$out = az vm list -g $resources.az_k8s_rg | Out-String | ConvertFrom-Json | ConvertObjectToHashtable
$k8sVmNames = @()
foreach($vm in $out) {
    $k8sVmNames += $vm.name
}
Set-EnvMapValue -Map $resources -Key "$ResourcePrefix.vm_names" -Value $k8sVmNames

# Write resources
Write-EnvResources -ResourcePath $ResourcePath -Resources $resources
