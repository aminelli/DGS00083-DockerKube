#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del Secret montato come volume (file su disco).
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 03 — Volume mount (file sensibili)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply Secret + Deployment..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\secret.yaml"
kubectl apply -f "$ScriptDir\deployment.yaml"
kubectl wait --for=condition=available deployment/secret-files-app --timeout=60s

$POD = kubectl get pod -l app=secret-files-app -o jsonpath='{.items[0].metadata.name}'
Write-Host "    Pod: $POD" -ForegroundColor White

Write-Host ""
Write-Host "==> Log del pod (struttura /etc/secrets/):" -ForegroundColor Green
kubectl logs $POD

Write-Host ""
Write-Host "==> Permessi file (defaultMode 0400):" -ForegroundColor Cyan
kubectl exec $POD -- ls -la /etc/secrets/

Write-Host ""
Write-Host "==> Il Secret è di sola lettura (tentativo scrittura → errore atteso):" -ForegroundColor Cyan
$err = kubectl exec $POD -- sh -c "echo test > /etc/secrets/test.txt 2>&1"
Write-Host "    Risultato: $err" -ForegroundColor Yellow

Write-Host ""
Write-Host "==> I Secret montati si aggiornano automaticamente come i ConfigMap?" -ForegroundColor Cyan
Write-Host "    Sì (senza subPath). Patch dimostrativo:" -ForegroundColor White
kubectl patch secret app-secret-files --type=merge `
    -p '{"stringData":{"api-key.txt":"sk-PATCHED-api-key-demo"}}'
Write-Host "    Secret patchato. Attendere ~60s per propagazione kubelet..." -ForegroundColor Yellow
Write-Host "    Poi: kubectl exec $POD -- cat /etc/secrets/api-key.txt" -ForegroundColor DarkYellow

Write-Host ""
Write-Host "[OK] Scenario 03 completato." -ForegroundColor Green
Write-Host "     I file hanno permessi 0400 (defaultMode). Volume mount = auto-update." -ForegroundColor Yellow
