#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy, sospensione e ripresa del CronJob suspend-demo.
    Dimostra il campo spec.suspend con patch imperativo e dichiarativo.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 04 — suspend (pausa e ripresa)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> [1/4] Apply CronJob (suspend: false)..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\cronjob.yaml"
kubectl get cronjob suspend-demo

Write-Host ""
Write-Host "==> Attendo la prima esecuzione (~70s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 70
Write-Host "    Job creati finora: $(kubectl get jobs -l app=suspend-demo --no-headers 2>$null | Measure-Object -Line | Select-Object -ExpandProperty Lines)"

Write-Host ""
Write-Host "==> [2/4] SOSPENSIONE del CronJob (patch suspend: true)..." -ForegroundColor Cyan
kubectl patch cronjob suspend-demo -p '{"spec":{"suspend":true}}'
kubectl get cronjob suspend-demo -o jsonpath='{"suspend: "}{.spec.suspend}{"\n"}'

Write-Host ""
Write-Host "==> Attendo 2 minuti per verificare che NON vengano creati nuovi Job..." -ForegroundColor Yellow
$jobsBefore = kubectl get jobs -l app=suspend-demo --no-headers 2>$null | Measure-Object -Line | Select-Object -ExpandProperty Lines
Start-Sleep -Seconds 125
$jobsAfter  = kubectl get jobs -l app=suspend-demo --no-headers 2>$null | Measure-Object -Line | Select-Object -ExpandProperty Lines
Write-Host "    Job prima della sospensione: $jobsBefore"
Write-Host "    Job dopo 2 minuti sospeso:   $jobsAfter"
if ($jobsBefore -eq $jobsAfter) {
    Write-Host "    [OK] Nessun nuovo Job durante la sospensione." -ForegroundColor Green
} else {
    Write-Host "    [INFO] Qualche Job potrebbe essere stato creato prima della sospensione." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> [3/4] RIPRESA del CronJob (patch suspend: false)..." -ForegroundColor Cyan
kubectl patch cronjob suspend-demo -p '{"spec":{"suspend":false}}'
kubectl get cronjob suspend-demo -o jsonpath='{"suspend: "}{.spec.suspend}{"\n"}'
Write-Host "    Il CronJob riprende la schedulazione al prossimo minuto."

Write-Host ""
Write-Host "==> [4/4] Attendo nuova esecuzione (~70s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 70
$jobsResume = kubectl get jobs -l app=suspend-demo --no-headers 2>$null | Measure-Object -Line | Select-Object -ExpandProperty Lines
Write-Host "    Job totali dopo ripresa: $jobsResume"
if ($jobsResume -gt $jobsAfter) {
    Write-Host "    [OK] Nuovo Job creato dopo la ripresa." -ForegroundColor Green
}

Write-Host ""
Write-Host "==> Metodi alternativi per sospendere:" -ForegroundColor Yellow
Write-Host '    kubectl patch cronjob suspend-demo -p "{\"spec\":{\"suspend\":true}}"'
Write-Host '    kubectl edit cronjob suspend-demo  (modifica spec.suspend nel YAML)'

Write-Host ""
Write-Host "[OK] Scenario 04 completato." -ForegroundColor Green
Write-Host "     suspend: true = pausa schedulazione, NON interrompe job attivi." -ForegroundColor Yellow
