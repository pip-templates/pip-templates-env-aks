#!/bin/sh

# Install brew package manager
xcode-select --install
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew update

# Install powershell
brew install openssl
brew install curl --with-openssl
brew cask install powershell

# Install docker and kubernetes
brew install kubernetes-cli
brew cask install docker
brew cask install minikube
brew cask install virtualbox

# Install ansible 
brew install ansible

# Install az cli
brew install azure-cli
