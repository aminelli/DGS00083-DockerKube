#Requires -Version 5.1
<#
.SYNOPSIS
    Test del DaemonSet base: un pod per ogni nodo, nomi e placement automatici.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 01 — DaemonSet base (un pod per nodo)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Nodi nel cluster:" -ForegroundColor Cyan
kubectl get nodes -o wide

$nodeCount = [int](kubectl get nodes --no-headers 2>$null | Measure-Object -Line).Lines
Write-Host ""
Write-Host "    Nodi trovati: $nodeCount"
Write-Host "    Il DaemonSet creerà 1 pod per ogni nodo → $nodeCount pod totali."

Write-Host ""
Write-Host "==> Apply DaemonSet node-info..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\daemonset.yaml"

Write-Host ""
Write-Host "==> Attendo che tutti i pod siano Ready..." -ForegroundColor Yellow
kubectl rollout status daemonset/node-info --timeout=90s

Write-Host ""
Write-Host "==> Pod creati (1 per nodo — colonna NODE mostra su quale nodo):" -ForegroundColor Green
kubectl get pods -l app=node-info -o wide

Write-Host ""
Write-Host "==> DaemonSet status:" -ForegroundColor Cyan
kubectl get daemonset node-info
Write-Host ""
kubectl get daemonset node-info -o jsonpath=`
    '{"DESIRED:   "}{.status.desiredNumberScheduled}{"\nCURRENT:   "}{.status.currentNumberScheduled}{"\nREADY:     "}{.status.numberReady}{"\nAVAILABLE: "}{.status.numberAvailable}{"\n"}'

Write-Host ""
Write-Host "==> Log del primo pod (info sul nodo):" -ForegroundColor Green
$firstPod = kubectl get pods -l app=node-info -o jsonpath='{.items[0].metadata.name}'
kubectl logs $firstPod | Select-String "nodo|Node|Pod:|CPU|Mem" | Select-Object -First 10

Write-Host ""
Write-Host "==> Variabili downwardAPI — nome nodo e IP iniettate nel pod:" -ForegroundColor Cyan
kubectl get pods -l app=node-info -o jsonpath=`
    '{range .items[*]}{"  pod="}{.metadata.name}{"  node="}{.spec.nodeName}{"  hostIP="}{.status.hostIP}{"  podIP="}{.status.podIP}{"\n"}{end}'

Write-Host ""
Write-Host "==> Differenza DaemonSet vs Deployment:" -ForegroundColor Yellow
Write-Host "    DaemonSet:  DESIRED = numero di nodi (si adatta automaticamente)"
Write-Host "    Deployment: DESIRED = replicas (fisso, scheduler sceglie il nodo)"

Write-Host ""
Write-Host "[OK] Scenario 01 completato." -ForegroundColor Green
