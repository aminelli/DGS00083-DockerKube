#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del CronJob base (ogni minuto).
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 01 — CronJob base (ogni minuto)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply CronJob..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\cronjob.yaml"

Write-Host ""
Write-Host "==> CronJob creato (inizialmente non ci sono job attivi):" -ForegroundColor Green
kubectl get cronjob hello-cronjob -o wide

Write-Host ""
Write-Host "==> Attendo la prima esecuzione (max 90s)..." -ForegroundColor Yellow
$deadline = (Get-Date).AddSeconds(90)
$found = $false
while ((Get-Date) -lt $deadline) {
    $jobs = kubectl get jobs -l "batch.kubernetes.io/controller-uid" --no-headers 2>$null |
            Select-String "hello-cronjob"
    if ($jobs) { $found = $true; break }
    Start-Sleep -Seconds 5
    Write-Host "    $(Get-Date -Format 'HH:mm:ss') — in attesa del primo Job..." -ForegroundColor DarkGray
}

if ($found) {
    Write-Host "    Primo Job apparso!" -ForegroundColor Green
} else {
    Write-Host "    Timeout: aspetta ancora qualche secondo e riesegui." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> Job associati al CronJob:" -ForegroundColor Green
kubectl get jobs | Select-String "hello-cronjob"

Write-Host ""
Write-Host "==> Dettaglio CronJob (lastScheduleTime, lastSuccessfulTime):" -ForegroundColor Cyan
kubectl get cronjob hello-cronjob -o jsonpath=`
    '{.status.lastScheduleTime}{"\n"}{.status.lastSuccessfulTime}{"\n"}'

Write-Host ""
Write-Host "==> Log dell'ultimo Job completato:" -ForegroundColor Green
$lastJob = kubectl get jobs --sort-by=.metadata.creationTimestamp -o name |
           Select-String "hello-cronjob" | Select-Object -Last 1
if ($lastJob) {
    $jobName = ($lastJob -split '/')[-1]
    $pod = kubectl get pods -l "batch.kubernetes.io/job-name=$jobName" `
               -o jsonpath='{.items[0].metadata.name}' 2>$null
    if ($pod) { kubectl logs $pod }
}

Write-Host ""
Write-Host "==> Spiegazione campi principali:" -ForegroundColor Yellow
Write-Host "    schedule:                    '* * * * *' = ogni minuto"
Write-Host "    successfulJobsHistoryLimit:  3 (tiene gli ultimi 3 completati)"
Write-Host "    failedJobsHistoryLimit:      1 (tiene l'ultimo fallito)"
Write-Host "    startingDeadlineSeconds:     60 (tollera 60s di ritardo)"
Write-Host "    ttlSecondsAfterFinished:     120 (elimina job dopo 2m dal completamento)"

Write-Host ""
Write-Host "[OK] Scenario 01 completato." -ForegroundColor Green
Write-Host "     Il CronJob continua a girare. Usa 99-cleanup-all.ps1 per fermarlo." -ForegroundColor Yellow
