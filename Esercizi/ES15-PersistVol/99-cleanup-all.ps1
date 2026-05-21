#Requires -Version 5.1
<#
.SYNOPSIS
    Rimuove tutte le risorse create dagli esempi PersistentVolume.
    NB: i PV con reclaimPolicy Retain non vengono eliminati automaticamente
    — il test li elimina esplicitamente.
#>
$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkRed
Write-Host "  Cleanup k8s-pv-examples" -ForegroundColor Red
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkRed

Write-Host ""
Write-Host "==> Rimozione Pod..." -ForegroundColor Cyan
kubectl delete pod `
    static-pv-writer `
    reclaim-writer `
    access-rwo-writer `
    access-rox-reader-1 `
    access-rox-reader-2 `
    --ignore-not-found --grace-period=0 --force

Write-Host "==> Rimozione Deployment..." -ForegroundColor Cyan
kubectl delete deployment dynamic-app expansion-app --ignore-not-found

Write-Host "==> Rimozione PVC..." -ForegroundColor Cyan
kubectl delete pvc `
    static-pvc `
    selector-pvc-gold `
    selector-pvc-silver `
    named-pvc `
    dynamic-pvc-a `
    dynamic-pvc-b `
    reclaim-retain-pvc `
    reclaim-delete-pvc `
    access-rwo-pvc `
    access-rox-pvc `
    access-rwop-pvc `
    expandable-pvc `
    --ignore-not-found

Write-Host "==> Rimozione PV (cluster-scoped, richiede delete esplicito)..." -ForegroundColor Cyan
kubectl delete pv `
    static-pv-large `
    static-pv-small `
    selector-pv-gold `
    selector-pv-silver `
    named-pv `
    reclaim-retain-pv `
    reclaim-delete-pv `
    access-rwo-pv `
    access-rox-pv `
    access-rwop-pv `
    --ignore-not-found

Write-Host "==> Rimozione StorageClass..." -ForegroundColor Cyan
kubectl delete storageclass kind-local-path expandable-storage --ignore-not-found

Write-Host ""
Write-Host "==> Verifica PV/PVC residui:" -ForegroundColor Green
$remaining = kubectl get pv,pvc 2>$null | Select-String `
    "static-pv|selector-pv|named-pv|reclaim-|access-|dynamic-pvc|expandable-pvc"
if ($remaining) { $remaining } else { Write-Host "    (nessuno — pulizia completa)" -ForegroundColor Green }

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
Write-Host "  [OK] Cleanup completato." -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
