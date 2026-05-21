#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test dei tre ConcurrencyPolicy (Allow / Forbid / Replace).
    I job durano ~70s per garantire sovrapposizioni visibili.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 02 — ConcurrencyPolicy (Allow / Forbid / Replace)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply tre CronJob..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\cronjob.yaml"

Write-Host ""
Write-Host "==> CronJob creati:" -ForegroundColor Green
kubectl get cronjob -l scenario=cronjob-concurrency -o wide

Write-Host ""
Write-Host "==> Attendo la prima esecuzione di ciascun CronJob (~90s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 70

Write-Host ""
Write-Host "==> Job attivi (dopo 70s, un job per CronJob dovrebbe essere ancora Running):" -ForegroundColor Green
kubectl get jobs -l scenario=cronjob-concurrency

Write-Host ""
Write-Host "==> Attendo il secondo trigger (+60s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 65

Write-Host ""
Write-Host "==> Stato dopo il secondo trigger:" -ForegroundColor Cyan
kubectl get jobs -l scenario=cronjob-concurrency

Write-Host ""
Write-Host "==> Analisi comportamento:" -ForegroundColor Yellow
Write-Host ""

# Allow: conta i pod attivi
$allowPods = kubectl get pods -l app=concurrency-allow --field-selector=status.phase=Running --no-headers 2>$null
$allowCount = if ($allowPods) { ($allowPods | Measure-Object -Line).Lines } else { 0 }
Write-Host "  [ALLOW]   Pod Running contemporanei: $allowCount" -ForegroundColor White
Write-Host "            → Atteso > 1 (esecuzioni parallele permesse)" -ForegroundColor DarkYellow

$forbidJobs = kubectl get jobs -l app=concurrency-forbid --no-headers 2>$null
$forbidCount = if ($forbidJobs) { ($forbidJobs | Measure-Object -Line).Lines } else { 0 }
Write-Host ""
Write-Host "  [FORBID]  Job totali: $forbidCount" -ForegroundColor White
Write-Host "            → Atteso = 1 (il secondo trigger è stato saltato)" -ForegroundColor DarkYellow

$replaceJobs = kubectl get jobs -l app=concurrency-replace --no-headers 2>$null
$replaceCount = if ($replaceJobs) { ($replaceJobs | Measure-Object -Line).Lines } else { 0 }
Write-Host ""
Write-Host "  [REPLACE] Job totali: $replaceCount" -ForegroundColor White
Write-Host "            → Il job precedente è stato cancellato e rimpiazzato" -ForegroundColor DarkYellow

Write-Host ""
Write-Host "[OK] Scenario 02 completato." -ForegroundColor Green
