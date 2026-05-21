#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del ConfigMap montato come volume (multi-file).
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 03 — Volume mount (multi-file)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply ConfigMap + Deployment..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\configmap.yaml"
kubectl apply -f "$ScriptDir\deployment.yaml"
kubectl wait --for=condition=available deployment/volume-files-app --timeout=60s

$POD = kubectl get pod -l app=volume-files-app -o jsonpath='{.items[0].metadata.name}'
Write-Host ""
Write-Host "==> Pod: $POD" -ForegroundColor White

Write-Host ""
Write-Host "==> Log del pod (struttura /etc/config/):" -ForegroundColor Green
kubectl logs $POD

Write-Host ""
Write-Host "==> Elenco file montati in /etc/config/ (via exec):" -ForegroundColor Cyan
kubectl exec $POD -- ls -la /etc/config/

Write-Host ""
Write-Host "==> Struttura symlink kubelet (aggiornamento atomico):" -ForegroundColor Cyan
kubectl exec $POD -- sh -c "ls -la /etc/config/ | head -20"

Write-Host ""
Write-Host "==> Lettura app.properties:" -ForegroundColor Green
kubectl exec $POD -- cat /etc/config/app.properties

Write-Host ""
Write-Host "==> Lettura logging.yaml:" -ForegroundColor Green
kubectl exec $POD -- cat /etc/config/logging.yaml

Write-Host ""
Write-Host "==> Verifica readOnly (tentativo scrittura, atteso errore):" -ForegroundColor Cyan
$writeErr = kubectl exec $POD -- sh -c "echo test > /etc/config/test.txt 2>&1"
if ($writeErr -match "read-only") {
    Write-Host "    [OK] Volume correttamente in sola lettura." -ForegroundColor Green
} else {
    Write-Host "    Risultato: $writeErr" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[OK] Scenario 03 completato." -ForegroundColor Green
Write-Host "     Ogni chiave del ConfigMap = un file in /etc/config/" -ForegroundColor Yellow
