#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del volume hostPath.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 02 — hostPath (filesystem del nodo)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply pod..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\pod.yaml"
kubectl wait --for=condition=Ready pod/hostpath-demo --timeout=60s

Write-Host ""
Write-Host "==> Log del pod (accesso al filesystem del nodo):" -ForegroundColor Green
kubectl logs hostpath-demo

Write-Host ""
Write-Host "==> File scritto dal pod sul nodo:" -ForegroundColor Cyan
Write-Host "    (verifica sul nodo Kind tramite exec nel pod stesso)"
kubectl exec hostpath-demo -- cat /host-tmp/from-pod.txt 2>/dev/null || `
    Write-Host "    (pod già terminato)" -ForegroundColor Yellow

Write-Host ""
Write-Host "==> Tipi hostPath disponibili:" -ForegroundColor Yellow
Write-Host "    DirectoryOrCreate  — crea dir se non esiste"
Write-Host "    Directory          — la dir DEVE esistere"
Write-Host "    FileOrCreate       — crea file se non esiste"
Write-Host "    File               — il file DEVE esistere"
Write-Host "    Socket             — socket UNIX"
Write-Host "    CharDevice         — device a caratteri"
Write-Host "    BlockDevice        — device a blocchi"
Write-Host ""
Write-Host "    ⚠ hostPath espone il nodo: NON usare in produzione!" -ForegroundColor Red

Write-Host ""
Write-Host "[OK] Scenario 02 completato." -ForegroundColor Green
