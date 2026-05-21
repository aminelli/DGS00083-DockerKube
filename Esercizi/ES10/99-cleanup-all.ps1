#Requires -Version 5.1
<#
.SYNOPSIS
    Rimuove tutte le risorse create dagli esempi Secret.
#>
$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkRed
Write-Host "  Cleanup k8s-secret-examples" -ForegroundColor Red
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkRed

Write-Host ""
Write-Host "==> Rimozione Pod..." -ForegroundColor Cyan
kubectl delete pod `
    opaque-secret-demo `
    envfrom-secret-demo `
    registry-pull-demo `
    sa-token-demo `
    --ignore-not-found --grace-period=0 --force

Write-Host "==> Rimozione Deployment..." -ForegroundColor Cyan
kubectl delete deployment `
    secret-files-app `
    --ignore-not-found

Write-Host "==> Rimozione Secret..." -ForegroundColor Cyan
kubectl delete secret `
    db-credentials `
    db-credentials-b64 `
    app-secrets-envfrom `
    app-secret-files `
    tls-demo-cert `
    registry-credentials `
    pod-reader-sa-token `
    --ignore-not-found

Write-Host "==> Rimozione ServiceAccount + RBAC..." -ForegroundColor Cyan
kubectl delete serviceaccount pod-reader-sa              --ignore-not-found
kubectl delete role            pod-reader-role           --ignore-not-found
kubectl delete rolebinding     pod-reader-binding        --ignore-not-found

Write-Host ""
Write-Host "==> Verifica (atteso: nessun risultato):" -ForegroundColor Green
kubectl get pod,deployment,secret,serviceaccount,role,rolebinding |
    Select-String -Pattern "opaque-secret|envfrom-secret|secret-files|registry-pull|sa-token|db-credentials|app-secrets|tls-demo|registry-cred|pod-reader"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
Write-Host "  [OK] Cleanup completato." -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGreen
