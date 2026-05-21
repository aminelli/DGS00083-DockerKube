#Requires -Version 5.1
<#
.SYNOPSIS
    Rimuove tutte le risorse create dagli esempi ConfigMap.
#>
$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkRed
Write-Host "  Cleanup k8s-configmap-examples" -ForegroundColor Red
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkRed

Write-Host ""
Write-Host "==> Rimozione Pod..." -ForegroundColor Cyan
kubectl delete pod `
    env-vars-demo `
    env-from-demo `
    immutable-reader `
    --ignore-not-found --grace-period=0 --force

Write-Host "==> Rimozione Deployment..." -ForegroundColor Cyan
kubectl delete deployment `
    volume-files-app `
    nginx-custom `
    webpage-server `
    --ignore-not-found

Write-Host "==> Rimozione Service..." -ForegroundColor Cyan
kubectl delete service `
    nginx-custom-svc `
    webpage-svc `
    --ignore-not-found

Write-Host "==> Rimozione ConfigMap..." -ForegroundColor Cyan
kubectl delete configmap `
    app-config-envvar `
    app-config-envfrom `
    app-config-files `
    nginx-custom-config `
    release-config-v1 `
    webpage-content `
    --ignore-not-found

Write-Host ""
Write-Host "==> Verifica (atteso: nessun risultato):" -ForegroundColor Green
kubectl get pod,deployment,service,configmap |
    Select-String -Pattern "env-vars-demo|env-from-demo|volume-files|nginx-custom|immutable-reader|webpage"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
Write-Host "  [OK] Cleanup completato." -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
