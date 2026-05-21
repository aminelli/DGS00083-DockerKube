#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del Job con completions sequenziali (4 run, 1 alla volta).
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO: Job Sequenziale (4 completions)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply Job..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\job.yaml"

Write-Host ""
Write-Host "==> Attesa completamento di tutte le 4 run sequenziali (timeout 180s)..." -ForegroundColor Cyan
kubectl wait --for=condition=complete job/job-sequential --timeout=180s

Write-Host ""
Write-Host "==> Stato Job (4 Pod creati in sequenza):" -ForegroundColor Green
kubectl get job job-sequential -o wide

Write-Host ""
Write-Host "==> Pod eseguiti:" -ForegroundColor Green
kubectl get pods -l scenario=job-completions -o wide

Write-Host ""
Write-Host "==> Log di tutti i Pod (ogni run è un Pod separato):" -ForegroundColor Green
$pods = kubectl get pods -l scenario=job-completions -o jsonpath="{.items[*].metadata.name}" 2>&1
$pods -split " " | ForEach-Object {
    if ($_) {
        Write-Host ""
        Write-Host "  --- Pod: $_ ---" -ForegroundColor DarkCyan
        kubectl logs $_ 2>&1
    }
}

Write-Host ""
Write-Host "[OK] Job sequenziale completato (4 item migrati uno alla volta)." -ForegroundColor Green
