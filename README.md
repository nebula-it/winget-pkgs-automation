[![Publish talosctl package](https://github.com/nebula-it/winget-pkgs-automation/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/nebula-it/winget-pkgs-automation/actions/workflows/main.yml)

# winget-pkgs-automation
Repo runs Github Action to deploy new package version automagically on Winget

# Submit a new Package
```
wingetcreate new --out $env:TEMP -t <github Token> https://github.com/cilium/cilium-cli/releases/download/v0.16.19/cilium-windows-amd64.zip https://github.com/cilium/cilium-cli/releases/download/v0.16.19/cilium-windows-arm64.zip
```