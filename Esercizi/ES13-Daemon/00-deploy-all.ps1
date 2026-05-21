#Requires -Version 5.1
<#
.SYNOPSIS
    Esegue tutti gli scenari DaemonSet in sequenza.
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
Write-Host "║       k8s-daemonset-examples — Deploy all                ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor DarkMagenta

Invoke-Scenario "DaemonSet base (un pod per nodo)"         "01-basic"          1
Invoke-Scenario "nodeSelector e nodeAffinity"              "02-node-selector"  2
Invoke-Scenario "Tolerations (control-plane + taint)"      "03-tolerations"    3
Invoke-Scenario "Risorse host (hostNetwork + hostPath)"    "04-host-resources" 4
Invoke-Scenario "Update Strategies (Rolling / OnDelete)"   "05-update-strategy" 5
Invoke-Scenario "Log Collector (pattern Fluentd/Filebeat)" "06-log-collector"  6

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor DarkGreen
Write-Host "║  Tutti gli scenari completati.                           ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "==> DaemonSet attivi:" -ForegroundColor Cyan
kubectl get daemonsets 2>$null
Write-Host ""
Write-Host "Esegui 99-cleanup-all.ps1 per rimuovere tutte le risorse." -ForegroundColor DarkYellow
