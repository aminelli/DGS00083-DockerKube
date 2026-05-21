#Requires -Version 5.1
<#
.SYNOPSIS
    Esegue tutti e 6 gli scenari ConfigMap in sequenza.
.PARAMETER Scenario
    Se specificato (1-6), esegue solo quello scenario.
#>
param([int]$Scenario = 0)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Invoke-Scenario {
    param([string]$Name, [string]$Folder, [int]$Num)
    if ($Scenario -ne 0 -and $Scenario -ne $Num) { return }
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host ("║  SCENARIO {0:D2} — {1,-37} ║" -f $Num, $Name) -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
    & "$ScriptDir\$Folder\test.ps1"
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor DarkMagenta
Write-Host "║     k8s-configmap-examples — Deploy all          ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor DarkMagenta

Invoke-Scenario "env var singole (valueFrom)"   "01-env-vars"        1
Invoke-Scenario "envFrom (import massivo)"       "02-env-from"        2
Invoke-Scenario "Volume mount multi-file"        "03-volume-files"    3
Invoke-Scenario "nginx config da ConfigMap"      "04-nginx-config"    4
Invoke-Scenario "ConfigMap immutabile"           "05-immutable"       5
Invoke-Scenario "Dynamic reload (volume)"        "06-dynamic-reload"  6

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor DarkGreen
Write-Host "║  Tutti gli scenari completati.                   ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "==> ConfigMap attivi:" -ForegroundColor Cyan
kubectl get configmap | Select-String -Pattern "app-config|nginx-custom|release-config|webpage-content"
Write-Host ""
Write-Host "Esegui 99-cleanup-all.ps1 per rimuovere tutte le risorse." -ForegroundColor DarkYellow
