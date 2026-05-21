#Requires -Version 5.1
<#
.SYNOPSIS
    Esegue tutti gli scenari PersistentVolume in sequenza.
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
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host ("║  SCENARIO {0:D2} — {1,-45} ║" -f $Num, $Name) -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
    & "$ScriptDir\$Folder\test.ps1"
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor DarkMagenta
Write-Host "║       k8s-pv-examples — Deploy all                      ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor DarkMagenta

Invoke-Scenario "Static Provisioning (PV + PVC manuale)"    "01-static-pv"          1
Invoke-Scenario "PVC labelSelector + volumeName"             "02-pvc-selector"       2
Invoke-Scenario "Dynamic Provisioning + StorageClass"        "03-dynamic-storageclass" 3
Invoke-Scenario "ReclaimPolicy: Retain vs Delete"            "04-reclaim-policy"     4
Invoke-Scenario "Access Modes (RWO / ROX / RWOP)"           "05-access-modes"       5
Invoke-Scenario "Volume Expansion (resize PVC)"              "06-volume-expansion"   6

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor DarkGreen
Write-Host "║  Tutti gli scenari completati.                           ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "==> PV e PVC attivi:" -ForegroundColor Cyan
kubectl get pv,pvc 2>$null
Write-Host ""
Write-Host "Esegui 99-cleanup-all.ps1 per rimuovere tutte le risorse." -ForegroundColor DarkYellow
