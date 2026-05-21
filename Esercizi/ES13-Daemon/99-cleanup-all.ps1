#Requires -Version 5.1
<#
.SYNOPSIS
    Rimuove tutte le risorse create dagli esempi DaemonSet.
#>
$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkRed
Write-Host "  Cleanup k8s-daemonset-examples" -ForegroundColor Red
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkRed

Write-Host ""
Write-Host "==> Rimozione DaemonSet..." -ForegroundColor Cyan
kubectl delete daemonset `
    node-info `
    selector-agent `
    affinity-agent `
    gpu-agent `
    worker-only-agent `
    all-nodes-agent `
    node-monitor `
    ds-rolling `
    ds-ondelete `
    log-collector `
    --ignore-not-found

Write-Host "==> Rimozione ConfigMap..." -ForegroundColor Cyan
kubectl delete configmap log-collector-config --ignore-not-found

Write-Host "==> Rimozione label dai nodi (cleanup scenario 02)..." -ForegroundColor Cyan
kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | Split-String " " |
    ForEach-Object {
        kubectl label node $_ monitoring- tier- gpu- --ignore-not-found 2>$null | Out-Null
    }

Write-Host ""
Write-Host "==> Verifica DaemonSet residui (scenario: ds-*):" -ForegroundColor Green
$res = kubectl get daemonsets -l 'scenario in (ds-basic,ds-selector,ds-tolerations,ds-host-resources,ds-update,ds-log-collector)' 2>$null
if ($res -and $res -notmatch "No resources") { $res }
else { Write-Host "    (nessuno — pulizia completa)" -ForegroundColor Green }

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
Write-Host "  [OK] Cleanup completato." -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
