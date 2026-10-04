<#
.SYNOPSIS
    Copy Fireside into a World of Warcraft AddOns directory.

.DESCRIPTION
    The addon files live at the repository root (the layout the BigWigs
    packager expects), so only the .toc and .lua files are copied: README,
    scripts and git metadata never reach the game folder.

.EXAMPLE
    .\scripts\deploy.ps1
    .\scripts\deploy.ps1 -AddOnsPath "D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns"
#>
param(
    # Set this once to your own AddOns folder, or pass -AddOnsPath each time.
    [string]$AddOnsPath = $env:WOW_ADDONS_PATH
)

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot

if (-not $AddOnsPath) {
    Write-Error "No AddOns path. Pass -AddOnsPath or set the WOW_ADDONS_PATH environment variable."
}
if (-not (Test-Path $AddOnsPath)) {
    Write-Error "AddOns path not found: $AddOnsPath"
}

$target = Join-Path $AddOnsPath "Fireside"

if (Test-Path $target) {
    Remove-Item -Recurse -Force $target
}
New-Item -ItemType Directory -Path $target | Out-Null
Get-ChildItem -Path $repo -File | Where-Object { $_.Extension -in ".toc", ".lua" } |
    Copy-Item -Destination $target

Write-Host "Deployed to $target" -ForegroundColor Green
Write-Host "Type /reload in game (ReloadUI is protected on the Forever beta, addon buttons cannot do it)."
