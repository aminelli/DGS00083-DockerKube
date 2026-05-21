#Requires -Version 5.1
<#
.SYNOPSIS
    Esegue tutti gli scenari Volume in sequenza.
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
    Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host ("║  SCENARIO {0:D2} — {1,-41} ║" -f $Num, $Name) -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
    & "$ScriptDir\$Folder\test.ps1"
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor DarkMagenta
Write-Host "║       k8s-volume-examples — Deploy all               ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor DarkMagenta

Invoke-Scenario "emptyDir (volume condiviso)"              "01-emptydir"      1
Invoke-Scenario "hostPath (filesystem del nodo)"           "02-hostpath"      2
Invoke-Scenario "projected (token + CM + Secret + down)"   "03-projected"     3
Invoke-Scenario "PersistentVolume + PVC (static)"          "04-pvc"           4
Invoke-Scenario "initContainer + emptyDir"                 "05-init-emptydir" 5
Invoke-Scenario "Dynamic PVC + StorageClass"               "06-dynamic-pvc"   6

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor DarkGreen
Write-Host "║  Tutti gli scenari completati.                       ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "==> Risorse attive:" -ForegroundColor Cyan
kubectl get pod,deployment,pv,pvc -o wide 2>$null | Select-String `
    "emptydir-demo|hostpath-demo|projected-demo|pvc-writer|pvc-reader|init-volume|dynamic-pvc"
Write-Host ""
Write-Host "Esegui 99-cleanup-all.ps1 per rimuovere tutte le risorse." -ForegroundColor DarkYellow
