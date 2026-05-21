#Requires -Version 5.1
<#
.SYNOPSIS
    Rimuove tutte le risorse create dagli esempi Volume.
#>
$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkRed
Write-Host "  Cleanup k8s-volume-examples" -ForegroundColor Red
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkRed

Write-Host ""
Write-Host "==> Rimozione Pod..." -ForegroundColor Cyan
kubectl delete pod `
    emptydir-demo `
    hostpath-demo `
    projected-demo `
    pvc-writer `
    pvc-reader `
    init-volume-demo `
    --ignore-not-found --grace-period=0 --force

Write-Host "==> Rimozione Deployment + Service..." -ForegroundColor Cyan
kubectl delete deployment dynamic-pvc-app  --ignore-not-found
kubectl delete service    dynamic-pvc-svc  --ignore-not-found

Write-Host "==> Rimozione ConfigMap + Secret (scenario 03)..." -ForegroundColor Cyan
kubectl delete configmap projected-app-config  --ignore-not-found
kubectl delete secret    projected-app-secret  --ignore-not-found

Write-Host "==> Rimozione PVC..." -ForegroundColor Cyan
kubectl delete pvc demo-pvc    --ignore-not-found
kubectl delete pvc dynamic-pvc --ignore-not-found

Write-Host "==> Rimozione PV (retention policy: Retain → richiede delete manuale)..." -ForegroundColor Cyan
kubectl delete pv demo-pv --ignore-not-found
# I PV dinamici vengono rimossi automaticamente con il PVC (ReclaimPolicy: Delete)

Write-Host ""
Write-Host "==> Verifica (atteso: nessun risultato):" -ForegroundColor Green
kubectl get pod,deployment,pvc,pv 2>$null | Select-String `
    "emptydir-demo|hostpath-demo|projected-demo|pvc-writer|pvc-reader|init-volume|dynamic-pvc|demo-pv"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
Write-Host "  [OK] Cleanup completato." -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
