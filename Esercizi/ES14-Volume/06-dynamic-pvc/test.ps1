#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del dynamic provisioning con StorageClass di Kind.
    Dimostra il contatore boot persistente tra riavvii del pod.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 06 — Dynamic PVC + StorageClass" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> StorageClass disponibili nel cluster:" -ForegroundColor Green
kubectl get storageclass

Write-Host ""
Write-Host "==> Apply PVC + Deployment + Service..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\deployment.yaml"

Write-Host ""
Write-Host "==> PVC creato dinamicamente (attesa Bound):" -ForegroundColor Yellow
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/dynamic-pvc --timeout=60s
kubectl get pvc dynamic-pvc
kubectl get pv | Select-String "dynamic-pvc"

Write-Host ""
Write-Host "==> Attendo Deployment ready..." -ForegroundColor Cyan
kubectl wait --for=condition=available deployment/dynamic-pvc-app --timeout=90s
kubectl get deploy dynamic-pvc-app

Write-Host ""
Write-Host "==> Test HTTP (port-forward):" -ForegroundColor Cyan
$job = Start-Job { kubectl port-forward svc/dynamic-pvc-svc 8091:80 }
Start-Sleep -Seconds 3
try {
    $r = Invoke-WebRequest -Uri "http://localhost:8091/" -UseBasicParsing -TimeoutSec 5
    Write-Host "    HTTP $($r.StatusCode) — Risposta ricevuta:" -ForegroundColor Green
    $r.Content | Select-String -Pattern "Boots:|Hostname:|Ora:"
} catch {
    Write-Host "    Port-forward non disponibile: $($_.Exception.Message)" -ForegroundColor Yellow
} finally {
    Stop-Job $job; Remove-Job $job -Force
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "==> Boot counter (contatore persistente sul volume):" -ForegroundColor Cyan
$pod = kubectl get pod -l app=dynamic-pvc-app -o jsonpath='{.items[0].metadata.name}'
kubectl exec $pod -- cat /usr/share/nginx/html/data/boots.txt

Write-Host ""
Write-Host "==> Riavvio del pod per dimostrare la persistenza..." -ForegroundColor Yellow
kubectl delete pod $pod --grace-period=0 --force 2>&1 | Out-Null
Start-Sleep -Seconds 5
kubectl wait --for=condition=available deployment/dynamic-pvc-app --timeout=60s
$pod2 = kubectl get pod -l app=dynamic-pvc-app -o jsonpath='{.items[0].metadata.name}'
Write-Host "    Boot counter dopo riavvio:" -ForegroundColor Green
kubectl exec $pod2 -- cat /usr/share/nginx/html/data/boots.txt

Write-Host ""
Write-Host "==> Il contatore è incrementato → il volume persiste tra i pod." -ForegroundColor Green

Write-Host ""
Write-Host "[OK] Scenario 06 completato." -ForegroundColor Green
Write-Host "     Dynamic provisioning crea il PV automaticamente al momento del bind." -ForegroundColor Yellow
