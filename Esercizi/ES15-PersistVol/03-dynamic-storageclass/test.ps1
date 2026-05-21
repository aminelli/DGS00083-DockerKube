#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del Dynamic Provisioning con StorageClass.
    Il PV viene creato AUTOMATICAMENTE dal provisioner.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 03 — Dynamic Provisioning + StorageClass" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> StorageClass nel cluster PRIMA del deploy:" -ForegroundColor Cyan
kubectl get storageclass

Write-Host ""
Write-Host "==> Apply StorageClass + PVC + Deployment..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\sc-pvc-deployment.yaml"

Write-Host ""
Write-Host "==> PVC in stato Pending (WaitForFirstConsumer = aspetta un pod):" -ForegroundColor Yellow
kubectl get pvc dynamic-pvc-a dynamic-pvc-b

Write-Host ""
Write-Host "==> PV esistenti PRIMA che il Deployment venga schedulato:" -ForegroundColor Yellow
kubectl get pv | Select-String "dynamic-pvc" | ForEach-Object { Write-Host "    $_" }
if (-not (kubectl get pv 2>$null | Select-String "dynamic-pvc")) {
    Write-Host "    (nessun PV ancora — WaitForFirstConsumer)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "==> Attendo Deployment ready (questo triggera la creazione del PV)..." -ForegroundColor Cyan
kubectl wait --for=condition=available deployment/dynamic-app --timeout=120s

Write-Host ""
Write-Host "==> PV creato AUTOMATICAMENTE dal provisioner rancher.io/local-path:" -ForegroundColor Green
kubectl get pv | Select-String "dynamic-pvc-a|kind-local-path"
kubectl get pvc dynamic-pvc-a dynamic-pvc-b

Write-Host ""
Write-Host "==> WaitForFirstConsumer: il PV viene creato SOLO quando un pod viene schedulato." -ForegroundColor Yellow
Write-Host "    Questo permette al provisioner di creare il volume sullo STESSO nodo del pod."

Write-Host ""
Write-Host "==> Log del pod (boot counter persistente):" -ForegroundColor Green
$pod = kubectl get pod -l app=dynamic-app -o jsonpath='{.items[0].metadata.name}'
kubectl logs $pod

Write-Host ""
Write-Host "==> Riavvio pod per dimostrare persistenza..." -ForegroundColor Cyan
kubectl delete pod $pod --grace-period=0 --force 2>&1 | Out-Null
Start-Sleep -Seconds 10
kubectl wait --for=condition=available deployment/dynamic-app --timeout=60s
$pod2 = kubectl get pod -l app=dynamic-app -o jsonpath='{.items[0].metadata.name}'
Write-Host "    Nuovo pod: $pod2"
Start-Sleep -Seconds 5
kubectl logs $pod2 | Select-String "Boot numero"

Write-Host ""
Write-Host "==> Confronto Static vs Dynamic Provisioning:" -ForegroundColor Yellow
Write-Host "    Static:  Admin crea PV manualmente → Developer crea PVC → binding"
Write-Host "    Dynamic: Developer crea PVC → StorageClass provisioner crea PV → binding"
Write-Host "    Dynamic è il metodo moderno; Static è usato per storage pre-esistente."

Write-Host ""
Write-Host "[OK] Scenario 03 completato." -ForegroundColor Green
