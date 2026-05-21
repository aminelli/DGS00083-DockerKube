#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del ConfigMap con envFrom (import massivo).
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 02 — envFrom (tutte le chiavi)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply ConfigMap + Pod..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\configmap.yaml"
kubectl apply -f "$ScriptDir\pod.yaml"

Write-Host ""
Write-Host "==> Attesa pod Running (timeout 60s)..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready pod/env-from-demo --timeout=60s

Write-Host ""
Write-Host "==> Log del pod (env vars dal ConfigMap):" -ForegroundColor Green
kubectl logs env-from-demo

Write-Host ""
Write-Host "==> Confronto: senza prefisso vs con prefisso CFG_" -ForegroundColor Cyan
Write-Host "    --- Senza prefisso ---" -ForegroundColor White
kubectl exec env-from-demo -- sh -c "env | grep '^APP_NAME\|^LOG_LEVEL\|^ENVIRONMENT'"
Write-Host "    --- Con prefisso CFG_ ---" -ForegroundColor White
kubectl exec env-from-demo -- sh -c "env | grep '^CFG_APP_NAME\|^CFG_LOG_LEVEL\|^CFG_ENVIRONMENT'"

Write-Host ""
Write-Host "==> Numero totale di env var nel container:" -ForegroundColor Cyan
kubectl exec env-from-demo -- sh -c "env | wc -l"

Write-Host ""
Write-Host "==> Chiavi del ConfigMap:" -ForegroundColor Green
kubectl get configmap app-config-envfrom -o jsonpath='{.data}' | ConvertFrom-Json | Format-List

Write-Host ""
Write-Host "[OK] Scenario 02 completato." -ForegroundColor Green
Write-Host "     envFrom importa tutte le chiavi; 'prefix' aggiunge un namespace alle variabili." -ForegroundColor Yellow
