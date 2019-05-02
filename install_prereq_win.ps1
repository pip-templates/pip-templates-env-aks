#!/usr/bin/env pwsh

Write-Host "Remember to run this script as Administrator!"

Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install docker and kubernetes
choco install --yes kubernetes-cli 
choco install --yes docker
choco install --yes virtualbox
# Version 0.26 has problems running with Hyper-V
choco install --yes minikube --version 0.25.2

# Install vagrant
choco install --yes vagrant

# Install Azure Cli
choco install --yes azure-cli
