#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del volume projected (SA token + ConfigMap + Secret + downwardAPI).
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 03 — projected (SA token + ConfigMap + Secret + downwardAPI)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply ConfigMap + Secret + Pod..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\pod.yaml"
kubectl wait --for=condition=Ready pod/projected-demo --timeout=60s

Write-Host ""
Write-Host "==> Log del pod (struttura del volume projected):" -ForegroundColor Green
kubectl logs projected-demo

Write-Host ""
Write-Host "==> Struttura del volume /projected/ (exec):" -ForegroundColor Cyan
kubectl exec projected-demo -- find /projected -type f | Sort-Object

Write-Host ""
Write-Host "==> Token SA proiettato (lunghezza, scade in 1h):" -ForegroundColor Cyan
kubectl exec projected-demo -- sh -c "wc -c < /projected/token"

Write-Host ""
Write-Host "==> DownwardAPI labels del pod:" -ForegroundColor Cyan
kubectl exec projected-demo -- cat /projected/podinfo/labels

Write-Host ""
Write-Host "==> Sorgenti del volume projected:" -ForegroundColor Yellow
Write-Host "    serviceAccountToken  — JWT con TTL (rinnovo automatico)"
Write-Host "    configMap            — file di configurazione"
Write-Host "    secret               — file sensibili (0400)"
Write-Host "    downwardAPI          — metadata del pod (labels, namespace, risorse)"

Write-Host ""
Write-Host "[OK] Scenario 03 completato." -ForegroundColor Green
