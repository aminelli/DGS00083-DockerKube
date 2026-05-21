#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del volume emptyDir condiviso tra due container.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 01 — emptyDir (volume condiviso tra container)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply pod (due container: writer + reader)..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\pod.yaml"

Write-Host ""
Write-Host "==> Attendo avvio pod (potrebbe richiedere qualche secondo)..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
kubectl get pod emptydir-demo -o wide

Write-Host ""
Write-Host "==> Log container 'writer' (prime righe):" -ForegroundColor Green
Start-Sleep -Seconds 10
kubectl logs emptydir-demo -c writer --tail=10

Write-Host ""
Write-Host "==> Log container 'reader' (file condiviso in tempo reale):" -ForegroundColor Green
kubectl logs emptydir-demo -c reader --tail=15

Write-Host ""
Write-Host "==> Eseguo 'ls /shared/' nel container writer:" -ForegroundColor Cyan
kubectl exec emptydir-demo -c writer -- ls -la /shared/ 2>/dev/null || `
    Write-Host "    (container già terminato — normale per restartPolicy: Never)" -ForegroundColor Yellow

Write-Host ""
Write-Host "==> Punti chiave emptyDir:" -ForegroundColor Yellow
Write-Host "    - Vita: legata al pod (non al container)"
Write-Host "    - Condiviso: tutti i container del pod lo vedono"
Write-Host "    - Default: su disco del nodo"
Write-Host "    - medium: Memory → tmpfs (RAM, più veloce)"
Write-Host "    - Distrutto quando il pod viene rimosso"

Write-Host ""
Write-Host "[OK] Scenario 01 completato." -ForegroundColor Green
