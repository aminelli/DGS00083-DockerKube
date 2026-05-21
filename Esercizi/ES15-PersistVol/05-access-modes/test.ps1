#Requires -Version 5.1
<#
.SYNOPSIS
    Test degli Access Mode: RWO, ROX, RWOP.
    Dimostra le limitazioni di montaggio concorrente.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 05 — Access Modes (RWO / ROX / RWOP)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply PV + PVC + Pod..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\pv-pvc-pods.yaml"

Write-Host ""
Write-Host "==> Attendo binding PVC..." -ForegroundColor Yellow
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/access-rwo-pvc  --timeout=30s
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/access-rox-pvc  --timeout=30s
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/access-rwop-pvc --timeout=30s

Write-Host ""
Write-Host "==> PVC e i loro access mode:" -ForegroundColor Green
kubectl get pvc -l scenario=pv-access -o custom-columns=`
    "PVC:.metadata.name,ACCESS:.spec.accessModes[0],STATUS:.status.phase,PV:.spec.volumeName"

Write-Host ""
Write-Host "==> Attendo pod..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready pod/access-rwo-writer    --timeout=60s
kubectl wait --for=condition=Ready pod/access-rox-reader-1  --timeout=60s
kubectl wait --for=condition=Ready pod/access-rox-reader-2  --timeout=60s

Write-Host ""
Write-Host "==> [RWO] ReadWriteOnce — un nodo in lettura/scrittura:" -ForegroundColor Cyan
kubectl logs access-rwo-writer | Select-String "RWO|Scritto"
Write-Host "    PVC in uso da un solo pod alla volta su un singolo nodo." -ForegroundColor DarkYellow

Write-Host ""
Write-Host "==> [ROX] ReadOnlyMany — due pod leggono lo STESSO PVC contemporaneamente:" -ForegroundColor Cyan
kubectl logs access-rox-reader-1 | Select-String "ROX|Dati"
kubectl logs access-rox-reader-2 | Select-String "ROX|Dati"
Write-Host ""
$r1 = kubectl get pod access-rox-reader-1 -o jsonpath='{.status.phase}'
$r2 = kubectl get pod access-rox-reader-2 -o jsonpath='{.status.phase}'
Write-Host "    reader-1 phase: $r1" -ForegroundColor White
Write-Host "    reader-2 phase: $r2" -ForegroundColor White
if ($r1 -eq "Running" -and $r2 -eq "Running") {
    Write-Host "    [OK] Due pod montano lo stesso PVC in sola lettura contemporaneamente." -ForegroundColor Green
}

Write-Host ""
Write-Host "==> [RWOP] ReadWriteOncePod — solo 1 pod può montarlo in R/W:" -ForegroundColor Cyan
$rwopPvc = kubectl get pvc access-rwop-pvc -o jsonpath='{.spec.accessModes[0]}'
Write-Host "    access-rwop-pvc accessMode: $rwopPvc"
Write-Host "    Se un secondo pod tentasse di montarlo, rimarrebbe Pending." -ForegroundColor DarkYellow

Write-Host ""
Write-Host "==> Tabella riepilogo Access Modes:" -ForegroundColor Yellow
Write-Host @"
    ┌────────────────────────┬──────────┬──────────────────────────────────────────┐
    │ Sigla                  │ Nodi R/W │ Tipico use case                          │
    ├────────────────────────┼──────────┼──────────────────────────────────────────┤
    │ RWO  ReadWriteOnce     │ 1 nodo   │ Database, StatefulSet, storage applicativo│
    │ ROX  ReadOnlyMany      │ N nodi   │ Dati statici condivisi (assets, config)   │
    │ RWX  ReadWriteMany     │ N nodi   │ NFS, CephFS — non supportato da hostPath  │
    │ RWOP ReadWriteOncePod  │ 1 pod    │ Garanzia che un solo pod scriva (k8s≥1.22)│
    └────────────────────────┴──────────┴──────────────────────────────────────────┘
"@

Write-Host ""
Write-Host "[OK] Scenario 05 completato." -ForegroundColor Green
