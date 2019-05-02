#!/usr/bin/env pwsh

param
(
    [Alias("c", "Path")]
    [Parameter(Mandatory=$false, Position=0)]
    [string] $ConfigPath
)

# Load support functions
$rootPath = $PSScriptRoot
if ($rootPath -eq "") { $rootPath = "." }
. "$($rootPath)/lib/include.ps1"
$rootPath = $PSScriptRoot
if ($rootPath -eq "") { $rootPath = "." }

switch ($config.env_type) {
    "cloud" { 
        . "$($rootPath)/cloud/switch_k8s.ps1" $ConfigPath
     }
    "local" { 
        . "$($rootPath)/local/switch_k8s.ps1" $ConfigPath
     }
     Default {
         Write-Host "Use cloud or local env to switch k8s or platform type not specified in config file. Please add 'env_type' to config."
     }
}



