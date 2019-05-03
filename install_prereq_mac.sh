#!/bin/sh

# Install brew package manager
xcode-select --install
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew update

# Install powershell
brew install openssl
brew install curl --with-openssl
brew cask install powershell

# Install az cli
brew install azure-cli
