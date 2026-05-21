#Requires -Version 5.1
<#
.SYNOPSIS
    Test di ReclaimPolicy Retain vs Delete.
    Dimostra lo stato del PV dopo l'eliminazione del PVC.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 04 — ReclaimPolicy: Retain vs Delete" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> [1/4] Apply PV + PVC + Pod scrittore..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\pv-pvc-pod.yaml"
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/reclaim-retain-pvc --timeout=30s
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/reclaim-delete-pvc --timeout=30s
kubectl wait --for=condition=Ready pod/reclaim-writer --timeout=60s
kubectl logs reclaim-writer

Write-Host ""
Write-Host "==> [2/4] Stato iniziale PV (entrambi Bound):" -ForegroundColor Green
kubectl get pv reclaim-retain-pv reclaim-delete-pv -o custom-columns=`
    "NAME:.metadata.name,POLICY:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase,CLAIM:.spec.claimRef.name"

Write-Host ""
Write-Host "==> [3/4] ELIMINO entrambi i PVC..." -ForegroundColor Red
Write-Host "    Prima elimino il pod che li usa..."
kubectl delete pod reclaim-writer --ignore-not-found --grace-period=0 --force 2>&1 | Out-Null
Start-Sleep -Seconds 3
kubectl delete pvc reclaim-retain-pvc reclaim-delete-pvc --ignore-not-found
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "==> [4/4] Stato PV DOPO l'eliminazione dei PVC:" -ForegroundColor Cyan
kubectl get pv reclaim-retain-pv reclaim-delete-pv 2>$null -o custom-columns=`
    "NAME:.metadata.name,POLICY:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase" |
    ForEach-Object { Write-Host "    $_" }

Write-Host ""
$retainPv = kubectl get pv reclaim-retain-pv 2>$null
$deletePv = kubectl get pv reclaim-delete-pv 2>$null

if ($retainPv) {
    $retainPhase = kubectl get pv reclaim-retain-pv -o jsonpath='{.status.phase}'
    Write-Host "  [RETAIN] reclaim-retain-pv → Phase: $retainPhase" -ForegroundColor Green
    Write-Host "           Il PV è ancora presente con i dati. Richiede pulizia manuale." -ForegroundColor Yellow
    Write-Host "           Per riutilizzarlo: kubectl patch pv reclaim-retain-pv -p '{\"spec\":{\"claimRef\":null}}'"
} else {
    Write-Host "  [RETAIN] reclaim-retain-pv non trovato (inatteso)" -ForegroundColor Red
}

if (-not $deletePv) {
    Write-Host ""
    Write-Host "  [DELETE] reclaim-delete-pv → eliminato automaticamente." -ForegroundColor Green
    Write-Host "           Con storage cloud (EBS, PD, etc.) anche il disco sarebbe stato eliminato." -ForegroundColor Yellow
} else {
    $deletePhase = kubectl get pv reclaim-delete-pv -o jsonpath='{.status.phase}'
    Write-Host ""
    Write-Host "  [DELETE] reclaim-delete-pv → Phase: $deletePhase" -ForegroundColor Yellow
    Write-Host "           (Con hostPath il PV viene eliminato ma il dir del nodo resta)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  Riepilogo:" -ForegroundColor Cyan
Write-Host "    Retain → dati sicuri, richiede intervento admin per riutilizzo"
Write-Host "    Delete → pulizia automatica, dati persi (⚠ irreversibile su storage cloud)"

Write-Host ""
Write-Host "[OK] Scenario 04 completato." -ForegroundColor Green
