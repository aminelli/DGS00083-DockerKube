#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del Secret Opaque (credenziali database via valueFrom).
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 01 — Secret Opaque (valueFrom)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply Secret + Pod..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\secret.yaml"
kubectl apply -f "$ScriptDir\pod.yaml"
kubectl wait --for=condition=Ready pod/opaque-secret-demo --timeout=60s

Write-Host ""
Write-Host "==> Il Secret NON mostra i valori in chiaro (solo base64):" -ForegroundColor Yellow
kubectl get secret db-credentials -o yaml |
    Select-String -Pattern "username|password|db-host|db-port|connection"

Write-Host ""
Write-Host "==> Decodifica manuale (solo per demo/debug):" -ForegroundColor Cyan
$b64user = kubectl get secret db-credentials -o jsonpath='{.data.username}'
$decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64user))
Write-Host "    username (base64): $b64user"
Write-Host "    username (decoded): $decoded" -ForegroundColor Green

Write-Host ""
Write-Host "==> Log del pod (env var iniettate dal Secret):" -ForegroundColor Green
kubectl logs opaque-secret-demo

Write-Host ""
Write-Host "==> Verifica via exec:" -ForegroundColor Cyan
kubectl exec opaque-secret-demo -- sh -c 'echo "DB_USER=$DB_USER DB_HOST=$DB_HOST DB_PORT=$DB_PORT"'

Write-Host ""
Write-Host "==> Confronto Secret 'stringData' vs 'data': entrambi identici nel cluster:" -ForegroundColor Cyan
$u1 = kubectl get secret db-credentials     -o jsonpath='{.data.username}'
$u2 = kubectl get secret db-credentials-b64 -o jsonpath='{.data.username}'
Write-Host "    db-credentials.username     = $u1"
Write-Host "    db-credentials-b64.username = $u2"
if ($u1 -eq $u2) {
    Write-Host "    [OK] Identici: stringData e data producono lo stesso risultato." -ForegroundColor Green
}

Write-Host ""
Write-Host "[OK] Scenario 01 completato." -ForegroundColor Green
Write-Host "     I valori base64 nel Secret sono decodificati da Kubernetes prima dell'iniezione." -ForegroundColor Yellow
