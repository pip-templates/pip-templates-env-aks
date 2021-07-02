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
    --location $(Get-EnvMapValue -Map $config -Key "$AzurePrefix.region")  | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

    if ($out -eq $null) {
        Write-Host "Can't create resource group '$resourceGroup'"
        return
    } else {
        Write-Host "Resource group '$resourceGroup' created."
    }
} else {
    Write-Host "Using existing resource group '$resourceGroup'."
}

# Create azure container registry
Write-Host "Creating container registry..."

$templateParams = @{
    az_region = Get-EnvMapValue -Map $config -Key "$AzurePrefix.region"
    container_registry_name = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.name"
    container_registry_sku = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.sku"
    container_registry_admin_enabled = Get-EnvMapValue -Map $config -Key "$ConfigPrefix.admin_enabled"
}
Build-EnvTemplate -InputPath "$($path)/templates/container_registry_params.json" `
-OutputPath "$($path)/../temp/container_registry_params.json" -Params1 $templateParams

$out = az group deployment create --name $(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.deployment_name") `
--resource-group $resourceGroup `
--template-file "$($path)/templates/container_registry_deploy.json" `
--parameters "$($path)/../temp/container_registry_params.json" | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

if ($out -eq $null) {
    Write-Error "Can't create container registry."
    return
} else {
    if ($LastExitCode -eq 0) {
        Write-Host "ACR deployment '$($out.name)' has been successfully deployed."

        Write-Host "Recieving acr credentials..."
        $out = az acr credential show --resource-group $resourceGroup `
            --name $(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.name") | Out-String | ConvertFrom-Json | ConvertObjectToHashtable

        Set-EnvMapValue -Map $resources -Key "$ResourcePrefix" -Value @{}
        Set-EnvMapValue -Map $resources -Key "$ResourcePrefix.passwords" -Value $out.passwords[0]
        Set-EnvMapValue -Map $resources -Key "$ResourcePrefix.server" -Value "$(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.name").azurecr.io"
        # Write resources
        Write-EnvResources -ResourcePath $ResourcePath -Resources $resources
    }
}

# Login to new private docker registry
#docker login -u $(Get-EnvMapValue -Map $config -Key "$ConfigPrefix.name") -p "$($(Get-EnvMapValue -Map $resources -Key "$ConfigPrefix.passwords")[0].value)"$(Get-EnvMapValue -Map $resources -Key "$ConfigPrefix.server")
