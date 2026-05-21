#Requires -Version 5.1
<#
.SYNOPSIS
    Test dei DaemonSet con tolerations: gira su control-plane e nodi tainted.
    Mostra la differenza tra DaemonSet con e senza toleration per control-plane.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 03 — DaemonSet con Tolerations" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Taint presenti sui nodi del cluster:" -ForegroundColor Cyan
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{": "}{range .spec.taints[*]}{.key}{"="}{.value}{"("}{.effect}{") "}{end}{"\n"}{end}' 2>$null |
    ForEach-Object { if ($_) { Write-Host "  $_" } else { Write-Host "  (nessun taint)" } }

Write-Host ""
Write-Host "==> Apply DaemonSet (worker-only, all-nodes, gpu-agent)..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\daemonset.yaml"
Start-Sleep -Seconds 10

Write-Host ""
Write-Host "==> [1/3] worker-only-agent (NESSUNA toleration per control-plane):" -ForegroundColor Yellow
kubectl get daemonset worker-only-agent -o jsonpath=`
    '{"DESIRED: "}{.status.desiredNumberScheduled}{"  READY: "}{.status.numberReady}{"\n"}'
kubectl get pods -l app=worker-only-agent -o wide 2>$null
# In Kind con 1 nodo che è anche control-plane: DESIRED=0 o READY=0
$workerDesired = kubectl get daemonset worker-only-agent -o jsonpath='{.status.desiredNumberScheduled}'
if ($workerDesired -eq "0") {
    Write-Host "    [ATTESO] DESIRED=0 — il nodo Kind è solo control-plane (tainted)." -ForegroundColor DarkYellow
    Write-Host "    Senza toleration, il DaemonSet non può schedulare pod su nodi tainted." -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "==> [2/3] all-nodes-agent (tolera control-plane e nodi problematici):" -ForegroundColor Green
kubectl rollout status daemonset/all-nodes-agent --timeout=60s
kubectl get daemonset all-nodes-agent -o jsonpath=`
    '{"DESIRED: "}{.status.desiredNumberScheduled}{"  READY: "}{.status.numberReady}{"\n"}'
kubectl get pods -l app=all-nodes-agent -o wide

Write-Host ""
Write-Host "==> [3/3] gpu-agent (richiede label gpu=true + toleration gpu:NoSchedule):" -ForegroundColor Yellow
$gpuDesired = kubectl get daemonset gpu-agent -o jsonpath='{.status.desiredNumberScheduled}'
Write-Host "    DESIRED: $gpuDesired (atteso: 0 — nessun nodo con label gpu=true)"

Write-Host ""
Write-Host "==> Confronto DESIRED tra i tre DaemonSet:" -ForegroundColor Cyan
kubectl get daemonset -l scenario=ds-tolerations -o custom-columns=`
    "NAME:.metadata.name,DESIRED:.status.desiredNumberScheduled,READY:.status.numberReady,AVAILABLE:.status.numberAvailable"

Write-Host ""
Write-Host "==> Toleration del all-nodes-agent (6 toleration dichiarate):" -ForegroundColor Green
kubectl get daemonset all-nodes-agent -o jsonpath='{range .spec.template.spec.tolerations[*]}  {"key="}{.key}{" effect="}{.effect}{"\n"}{end}'

Write-Host ""
Write-Host "[OK] Scenario 03 completato." -ForegroundColor Green
Write-Host "     worker-only: 0 pod (bloccato dal taint control-plane)" -ForegroundColor DarkYellow
Write-Host "     all-nodes:   1+ pod (tolera il taint control-plane)" -ForegroundColor Green
