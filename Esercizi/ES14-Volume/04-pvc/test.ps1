#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test di PersistentVolume + PVC con provisioning statico.
    Dimostra la persistenza dei dati tra due pod successivi.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 04 — PersistentVolume + PVC (static provisioning)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> [1/4] Creazione PV + PVC + Pod writer..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\pv-pvc-pod.yaml"

Write-Host ""
Write-Host "==> Stato PV:" -ForegroundColor Green
kubectl get pv demo-pv
Write-Host ""
Write-Host "==> Stato PVC (attesa Bound):" -ForegroundColor Green
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/demo-pvc --timeout=30s
kubectl get pvc demo-pvc

Write-Host ""
Write-Host "==> [2/4] Attendo completamento pod writer..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready pod/pvc-writer --timeout=60s
kubectl logs pvc-writer
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/pvc-writer --timeout=60s
Write-Host "    Writer terminato." -ForegroundColor Green

Write-Host ""
Write-Host "==> [3/4] Avvio pod reader per verificare la persistenza..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\pvc-reader.yaml"
kubectl wait --for=condition=Ready pod/pvc-reader --timeout=60s

Write-Host ""
Write-Host "==> Log del reader (dati scritti dal writer precedente):" -ForegroundColor Green
kubectl logs pvc-reader

Write-Host ""
Write-Host "==> [4/4] Ciclo di vita PV/PVC:" -ForegroundColor Yellow
kubectl get pv,pvc

Write-Host ""
Write-Host "==> Access Modes disponibili:" -ForegroundColor Yellow
Write-Host "    RWO  (ReadWriteOnce)   — 1 nodo in lettura/scrittura"
Write-Host "    ROX  (ReadOnlyMany)    — N nodi in sola lettura"
Write-Host "    RWX  (ReadWriteMany)   — N nodi in lettura/scrittura (NFS, CephFS...)"
Write-Host "    RWOP (ReadWriteOncePod) — 1 pod (k8s >= 1.22)"

Write-Host ""
Write-Host "==> Reclaim Policy:" -ForegroundColor Yellow
Write-Host "    Retain  — PV resta dopo release PVC (dati sicuri)"
Write-Host "    Delete  — PV e storage eliminati automaticamente"
Write-Host "    Recycle — deprecated"

Write-Host ""
Write-Host "[OK] Scenario 04 completato." -ForegroundColor Green
Write-Host "     I dati sul PV sopravvivono alla terminazione dei pod." -ForegroundColor Yellow
