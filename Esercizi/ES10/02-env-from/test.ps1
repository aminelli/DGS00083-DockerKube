#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del Secret con envFrom (import massivo).
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 02 — envFrom.secretRef" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply Secret + Pod..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\secret.yaml"
kubectl apply -f "$ScriptDir\pod.yaml"
kubectl wait --for=condition=Ready pod/envfrom-secret-demo --timeout=60s

Write-Host ""
Write-Host "==> Chiavi nel Secret (nomi, non valori):" -ForegroundColor Green
kubectl get secret app-secrets-envfrom -o jsonpath='{.data}' |
    ConvertFrom-Json | Get-Member -MemberType NoteProperty | Select-Object Name

Write-Host ""
Write-Host "==> Log del pod (i valori sono mascherati in <HIDDEN>):" -ForegroundColor Green
kubectl logs envfrom-secret-demo

Write-Host ""
Write-Host "==> Verifica: le chiavi sono env var nel container:" -ForegroundColor Cyan
kubectl exec envfrom-secret-demo -- sh -c "env | grep '^DB_HOST\|^JWT_SECRET\|^API_KEY' | sed 's/=.*/=<HIDDEN>'"

Write-Host ""
Write-Host "==> Con prefisso SEC_:" -ForegroundColor Cyan
kubectl exec envfrom-secret-demo -- sh -c "env | grep '^SEC_DB_HOST\|^SEC_JWT' | sed 's/=.*/=<HIDDEN>'"

Write-Host ""
Write-Host "[OK] Scenario 02 completato." -ForegroundColor Green
Write-Host "     envFrom.secretRef importa tutte le chiavi; 'prefix' le isola." -ForegroundColor Yellow
