#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del CronJob semplice.
.DESCRIPTION
    Applica il CronJob (schedule: ogni 2 min), attende la prima esecuzione,
    mostra i log e lo stato della history. Permette anche di triggerare
    manualmente un'esecuzione immediata.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO: CronJob Semplice (ogni 2 min)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply CronJob..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\cronjob.yaml"

Write-Host ""
Write-Host "==> Stato CronJob (LAST SCHEDULE sarà <none> finché non scatta):" -ForegroundColor Green
kubectl get cronjob cronjob-simple

# Trigger manuale immediato senza aspettare lo schedule
Write-Host ""
Write-Host "==> Trigger manuale di un'esecuzione immediata..." -ForegroundColor Cyan
kubectl create job --from=cronjob/cronjob-simple cronjob-simple-manual-001 2>&1

Write-Host ""
Write-Host "==> Attesa completamento run manuale (timeout 60s)..." -ForegroundColor Cyan
kubectl wait --for=condition=complete job/cronjob-simple-manual-001 --timeout=60s

Write-Host ""
Write-Host "==> Log dell'esecuzione:" -ForegroundColor Green
kubectl logs job/cronjob-simple-manual-001

Write-Host ""
Write-Host "==> History Job del CronJob (ultimi 3 ok, 1 failed):" -ForegroundColor Green
kubectl get jobs -l "scenario=cronjob-simple" -o wide

Write-Host ""
Write-Host "==> Prossimo schedule previsto:" -ForegroundColor Green
kubectl get cronjob cronjob-simple -o jsonpath="{.status.nextScheduleTime}{'\n'}"

Write-Host ""
Write-Host "[OK] CronJob semplice attivo. Eseguirà automaticamente ogni 2 minuti." -ForegroundColor Green
Write-Host "     Per eliminarlo: kubectl delete cronjob cronjob-simple" -ForegroundColor Yellow
