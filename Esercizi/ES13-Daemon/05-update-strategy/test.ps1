#Requires -Version 5.1
<#
.SYNOPSIS
    Test delle update strategies: RollingUpdate con maxUnavailable e OnDelete.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 05 — Update Strategies (RollingUpdate / OnDelete)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Deploy ds-rolling (RollingUpdate) + ds-ondelete (OnDelete)..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\daemonset.yaml"
kubectl rollout status daemonset/ds-rolling  --timeout=60s
kubectl rollout status daemonset/ds-ondelete --timeout=60s

Write-Host ""
Write-Host "==> Versione iniziale (v1):" -ForegroundColor Green
kubectl get pods -l scenario=ds-update -o custom-columns=`
    "POD:.metadata.name,NODE:.spec.nodeName,VERSION:.metadata.labels.version"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkYellow
Write-Host "  [A] RollingUpdate: aggiornamento automatico nodo per nodo" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkYellow

Write-Host ""
Write-Host "==> Aggiorno ds-rolling a v2..." -ForegroundColor Cyan
kubectl patch daemonset ds-rolling --type=strategic-merge -p `
    '{"spec":{"template":{"metadata":{"labels":{"version":"v2"}},"spec":{"containers":[{"name":"agent","env":[{"name":"NODE_NAME","valueFrom":{"fieldRef":{"fieldPath":"spec.nodeName"}}},{"name":"APP_VERSION","value":"v2"}]}]}}}}'
kubectl rollout status daemonset/ds-rolling --timeout=60s

Write-Host ""
Write-Host "==> ds-rolling aggiornato a v2 (automaticamente su tutti i nodi):" -ForegroundColor Green
kubectl get pods -l app=ds-rolling -o custom-columns=`
    "POD:.metadata.name,NODE:.spec.nodeName,VERSION:.metadata.labels.version"

Write-Host ""
Write-Host "==> Cronologia rollout ds-rolling:" -ForegroundColor Cyan
kubectl rollout history daemonset/ds-rolling

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkYellow
Write-Host "  [B] OnDelete: aggiornamento solo su eliminazione manuale del pod" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkYellow

Write-Host ""
Write-Host "==> Aggiorno il template di ds-ondelete a v2 (i pod NON cambiano)..." -ForegroundColor Cyan
kubectl patch daemonset ds-ondelete --type=strategic-merge -p `
    '{"spec":{"template":{"spec":{"containers":[{"name":"agent","env":[{"name":"NODE_NAME","valueFrom":{"fieldRef":{"fieldPath":"spec.nodeName"}}},{"name":"APP_VERSION","value":"v2"}]}]}}}}'
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "==> ds-ondelete PRIMA dell'eliminazione manuale (ancora v1):" -ForegroundColor Yellow
kubectl get pods -l app=ds-ondelete
Write-Host "    Template aggiornato a v2, ma il pod non viene ricreato." -ForegroundColor DarkYellow

Write-Host ""
Write-Host "==> Elimino manualmente il pod ds-ondelete → ricreato con v2:" -ForegroundColor Cyan
$onDeletePod = kubectl get pods -l app=ds-ondelete -o jsonpath='{.items[0].metadata.name}'
kubectl delete pod $onDeletePod --grace-period=0 --force 2>&1 | Out-Null
kubectl rollout status daemonset/ds-ondelete --timeout=30s

Write-Host ""
Write-Host "==> ds-ondelete dopo la ricreazione manuale:" -ForegroundColor Green
kubectl exec (kubectl get pods -l app=ds-ondelete -o jsonpath='{.items[0].metadata.name}') `
    -- sh -c 'echo "version=$APP_VERSION"' 2>$null

Write-Host ""
Write-Host "[OK] Scenario 05 completato." -ForegroundColor Green
