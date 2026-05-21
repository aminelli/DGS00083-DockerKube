#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del Job parallelo (completionMode: Indexed).
.DESCRIPTION
    Avvia 6 unità di lavoro con 3 worker attivi contemporaneamente.
    Ogni worker conosce il proprio indice (0-5) tramite JOB_COMPLETION_INDEX.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO: Job Parallelo (Indexed, 3x6)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply Job..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\job.yaml"

Write-Host ""
Write-Host "==> Monitoraggio Pod in tempo reale (attendere completamento)..." -ForegroundColor Cyan
Write-Host "    (parallelism=3: vedrai 3 pod attivi contemporaneamente)" -ForegroundColor Gray
Write-Host ""

# Polling finché tutti i completions non sono pronti
$timeout = 180
$elapsed = 0
do {
    $status = kubectl get job job-parallel -o jsonpath="{.status.succeeded}" 2>&1
    $pods   = kubectl get pods -l scenario=job-parallel --no-headers 2>&1
    Write-Host "  [${elapsed}s] Completati: $status/6  |  Pod attivi:" -ForegroundColor Gray
    $pods | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($status -eq "6") { break }
    Start-Sleep -Seconds 5
    $elapsed += 5
} while ($elapsed -lt $timeout)

Write-Host ""
Write-Host "==> Stato Job finale:" -ForegroundColor Green
kubectl get job job-parallel -o wide

Write-Host ""
Write-Host "==> Log di ogni worker (indici 0-5):" -ForegroundColor Green
for ($i = 0; $i -le 5; $i++) {
    $podName = kubectl get pods -l scenario=job-parallel `
        -o jsonpath="{.items[$i].metadata.name}" 2>&1
    if ($podName -and $podName -notmatch "Error") {
        Write-Host ""
        Write-Host "  --- Worker indice $i ($podName) ---" -ForegroundColor DarkCyan
        kubectl logs $podName 2>&1
    }
}

Write-Host ""
Write-Host "[OK] Job parallelo completato (6 shard elaborati da 3 worker)." -ForegroundColor Green
