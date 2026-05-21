#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del ConfigMap con variabili d'ambiente singole (valueFrom).
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 01 — env var singole (valueFrom)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply ConfigMap + Pod..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\configmap.yaml"
kubectl apply -f "$ScriptDir\pod.yaml"

Write-Host ""
Write-Host "==> Attesa pod Running (timeout 60s)..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready pod/env-vars-demo --timeout=60s

Write-Host ""
Write-Host "==> Log del pod (variabili stampate all'avvio):" -ForegroundColor Green
kubectl logs env-vars-demo

Write-Host ""
Write-Host "==> Verifica singola chiave via exec:" -ForegroundColor Cyan
kubectl exec env-vars-demo -- sh -c 'echo "DB_HOST=$DB_HOST | LOG_LEVEL=$LOG_LEVEL"'

Write-Host ""
Write-Host "==> Chiave opzionale mancante (non causa errore con optional:true):" -ForegroundColor Cyan
kubectl exec env-vars-demo -- sh -c 'echo "OPTIONAL_MISSING=${OPTIONAL_MISSING:-<vuota>}"'

Write-Host ""
Write-Host "==> Ispezione ConfigMap:" -ForegroundColor Green
kubectl get configmap app-config-envvar -o yaml

Write-Host ""
Write-Host "[OK] Scenario 01 completato." -ForegroundColor Green
Write-Host "     Il pod usa valueFrom.configMapKeyRef per ogni variabile." -ForegroundColor Yellow
