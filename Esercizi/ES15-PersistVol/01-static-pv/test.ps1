#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del provisioning statico (PV manuale + PVC + Pod).
    Dimostra il flusso admin → developer → pod.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 01 — Static Provisioning (PV manuale)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> [ADMIN] Creo i PersistentVolume (risorsa cluster-scoped)..." -ForegroundColor Yellow
kubectl apply -f "$ScriptDir\pv-pvc-pod.yaml"

Write-Host ""
Write-Host "==> PV creati (Available = liberi, non ancora bound):" -ForegroundColor Green
kubectl get pv static-pv-large static-pv-small

Write-Host ""
Write-Host "==> [DEVELOPER] PVC creato — Kubernetes lo abbina al PV compatibile..." -ForegroundColor Cyan
Write-Host "    La richiesta è 200Mi, i PV disponibili sono 500Mi e 100Mi."
Write-Host "    Kubernetes sceglie il più piccolo che soddisfa la richiesta → 500Mi (unico >= 200Mi)."
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/static-pvc --timeout=30s
kubectl get pvc static-pvc

Write-Host ""
Write-Host "==> Stato PV dopo il binding:" -ForegroundColor Green
kubectl get pv static-pv-large static-pv-small
Write-Host "    static-pv-large → Bound (abbinato al PVC)"
Write-Host "    static-pv-small → Available (non abbinato: troppo piccolo per 200Mi)"

Write-Host ""
Write-Host "==> Dettaglio binding PVC → PV:" -ForegroundColor Cyan
kubectl get pvc static-pvc -o jsonpath=`
    '{"PVC:        "}{.metadata.name}{"\nPV legato:  "}{.spec.volumeName}{"\nPhase:      "}{.status.phase}{"\nCapacità:   "}{.status.capacity.storage}{"\n"}'

Write-Host ""
Write-Host "==> [POD] Apply pod scrittore..." -ForegroundColor Cyan
kubectl wait --for=condition=Ready pod/static-pv-writer --timeout=60s
kubectl logs static-pv-writer

Write-Host ""
Write-Host "==> Persistenza: ricreo il pod e verifico che i dati siano ancora presenti..." -ForegroundColor Yellow
kubectl delete pod static-pv-writer --ignore-not-found --grace-period=0 --force 2>&1 | Out-Null
Start-Sleep -Seconds 3
kubectl apply -f "$ScriptDir\pv-pvc-pod.yaml" 2>&1 | Select-String "pod/"
kubectl wait --for=condition=Ready pod/static-pv-writer --timeout=60s
Write-Host ""
Write-Host "==> Log dopo ricreazione (sessions.log deve contenere DUE righe):" -ForegroundColor Green
kubectl logs static-pv-writer | Select-String "Sessione"

Write-Host ""
Write-Host "[OK] Scenario 01 completato." -ForegroundColor Green
Write-Host "     PV (cluster) → PVC (namespace) → Pod: flusso admin/developer separato." -ForegroundColor Yellow
