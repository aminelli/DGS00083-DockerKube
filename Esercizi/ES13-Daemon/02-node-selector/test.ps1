#Requires -Version 5.1
<#
.SYNOPSIS
    Test del DaemonSet con nodeSelector e nodeAffinity.
    Etichetta i nodi, poi applica i DaemonSet e verifica il placement.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 02 — DaemonSet con nodeSelector / nodeAffinity" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Nodi disponibili:" -ForegroundColor Cyan
kubectl get nodes --show-labels | ForEach-Object { Write-Host "  $_" }

# In Kind single-node c'è solo un nodo (il control-plane funge anche da worker)
$nodes = kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | Split-String " "
$firstNode = $nodes[0]

Write-Host ""
Write-Host "==> [A] Aggiungo label 'monitoring=enabled' al nodo $firstNode..." -ForegroundColor Yellow
kubectl label node $firstNode monitoring=enabled --overwrite

Write-Host ""
Write-Host "==> [B] Aggiungo label 'tier=worker' al nodo $firstNode..." -ForegroundColor Yellow
kubectl label node $firstNode tier=worker --overwrite

Write-Host ""
Write-Host "==> Nodo $firstNode con le nuove label:" -ForegroundColor Green
kubectl get node $firstNode --show-labels

Write-Host ""
Write-Host "==> Apply DaemonSet con nodeSelector e nodeAffinity..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\daemonset.yaml"

Write-Host ""
Write-Host "==> Attendo pod selector-agent..." -ForegroundColor Yellow
kubectl rollout status daemonset/selector-agent --timeout=60s
Write-Host ""
Write-Host "==> Attendo pod affinity-agent (richiede tier=worker, no maintenance)..." -ForegroundColor Yellow
kubectl rollout status daemonset/affinity-agent --timeout=60s

Write-Host ""
Write-Host "==> Placement dei pod:" -ForegroundColor Green
kubectl get pods -l scenario=ds-selector -o wide

Write-Host ""
Write-Host "==> Verifica nodeSelector (selector-agent):" -ForegroundColor Cyan
$selectorNode = kubectl get pods -l app=selector-agent -o jsonpath='{.items[0].spec.nodeName}' 2>$null
if ($selectorNode) {
    $hasLabel = kubectl get node $selectorNode --show-labels 2>$null | Select-String "monitoring=enabled"
    if ($hasLabel) {
        Write-Host "    [OK] selector-agent gira su $selectorNode (ha label monitoring=enabled)" -ForegroundColor Green
    }
} else {
    Write-Host "    (nessun nodo con monitoring=enabled — nessun pod schedulato)" -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "==> gpu-agent: DESIRED=0 (nessun nodo con label gpu=true):" -ForegroundColor Yellow
kubectl get daemonset gpu-agent -o jsonpath='{"DESIRED: "}{.status.desiredNumberScheduled}{"\n"}'
Write-Host "    Aggiungi 'kubectl label node $firstNode gpu=true' per vedere il pod avviarsi."

Write-Host ""
Write-Host "==> Cleanup label (ripristino)..." -ForegroundColor DarkGray
kubectl label node $firstNode monitoring- tier- --ignore-not-found 2>$null | Out-Null

Write-Host ""
Write-Host "[OK] Scenario 02 completato." -ForegroundColor Green
