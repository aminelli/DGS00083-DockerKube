#Requires -Version 5.1
<#
.SYNOPSIS
    Esegue tutti e 6 gli scenari Secret in sequenza.
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
Write-Host "║      k8s-secret-examples — Deploy all            ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor DarkMagenta

Invoke-Scenario "Opaque + valueFrom"           "01-opaque"          1
Invoke-Scenario "envFrom.secretRef"            "02-env-from"        2
Invoke-Scenario "Volume mount (file)"          "03-volume-files"    3
Invoke-Scenario "TLS Secret"                   "04-tls"             4
Invoke-Scenario "Docker Registry pull Secret"  "05-docker-registry" 5
Invoke-Scenario "ServiceAccount + token + RBAC" "06-service-account" 6

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor DarkGreen
Write-Host "║  Tutti gli scenari completati.                   ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor DarkGreen
Write-Host ""
Write-Host "==> Secret attivi:" -ForegroundColor Cyan
kubectl get secret | Select-String -Pattern "db-credentials|app-secrets|app-secret-files|tls-demo|registry-cred|pod-reader"
Write-Host ""
Write-Host "Esegui 99-cleanup-all.ps1 per rimuovere tutte le risorse." -ForegroundColor DarkYellow
