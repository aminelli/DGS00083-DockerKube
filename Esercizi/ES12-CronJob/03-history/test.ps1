#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test dei tre CronJob con history limits differenti.
    Dimostra quanti Job vengono conservati nella lista.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 03 — History limits (long / short / none)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply tre CronJob..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\cronjob.yaml"

Write-Host ""
Write-Host "==> Configurazione history limits:" -ForegroundColor Yellow
Write-Host "    history-long:  successfulJobsHistoryLimit=10  failedJobsHistoryLimit=5"
Write-Host "    history-short: successfulJobsHistoryLimit=1   failedJobsHistoryLimit=1"
Write-Host "    history-none:  successfulJobsHistoryLimit=0   failedJobsHistoryLimit=0"

Write-Host ""
Write-Host "==> Attendo 3 cicli di esecuzione (~3 minuti)..." -ForegroundColor Yellow
for ($i = 1; $i -le 3; $i++) {
    Write-Host "    Ciclo $i/3 — $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor DarkGray
    Start-Sleep -Seconds 65
    Write-Host "    Job visibili dopo ciclo ${i}:" -ForegroundColor White
    Write-Host "      history-long:  $(kubectl get jobs -l app=history-long  --no-headers 2>$null | Measure-Object -Line | Select-Object -ExpandProperty Lines) job"
    Write-Host "      history-short: $(kubectl get jobs -l app=history-short --no-headers 2>$null | Measure-Object -Line | Select-Object -ExpandProperty Lines) job"
    Write-Host "      history-none:  $(kubectl get jobs -l app=history-none  --no-headers 2>$null | Measure-Object -Line | Select-Object -ExpandProperty Lines) job"
}

Write-Host ""
Write-Host "==> Stato finale:" -ForegroundColor Green
kubectl get jobs -l scenario=cronjob-history

Write-Host ""
Write-Host "==> history-long conserva tutti i job (fino a 10):" -ForegroundColor Yellow
kubectl get jobs -l app=history-long --sort-by=.metadata.creationTimestamp

Write-Host ""
Write-Host "==> history-short conserva solo l'ultimo (max 1):" -ForegroundColor Yellow
kubectl get jobs -l app=history-short

Write-Host ""
Write-Host "==> history-none: nessun job nella lista:" -ForegroundColor Yellow
$noJobs = kubectl get jobs -l app=history-none --no-headers 2>$null
if (-not $noJobs) { Write-Host "    (nessun job, come atteso)" -ForegroundColor Green }
else { $noJobs }

Write-Host ""
Write-Host "[OK] Scenario 03 completato." -ForegroundColor Green
Write-Host "     successfulJobsHistoryLimit=0 riduce l'inquinamento dello stato del cluster." -ForegroundColor Yellow
