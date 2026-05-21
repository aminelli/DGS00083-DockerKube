#Requires -Version 5.1
<#
.SYNOPSIS
    Test del PVC con labelSelector e volumeName per binding specifico.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 02 — PVC con labelSelector e volumeName" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply PV (gold, silver, named) + PVC..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\pv-pvc.yaml"

Write-Host ""
Write-Host "==> Attendo binding di tutti i PVC..." -ForegroundColor Yellow
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/selector-pvc-gold   --timeout=30s
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/selector-pvc-silver --timeout=30s
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/named-pvc           --timeout=30s

Write-Host ""
Write-Host "==> Binding risultante (PVC → PV):" -ForegroundColor Green
kubectl get pvc selector-pvc-gold selector-pvc-silver named-pvc -o custom-columns=`
    "PVC:.metadata.name,PV:.spec.volumeName,STATUS:.status.phase,CAPACITY:.status.capacity.storage"

Write-Host ""
Write-Host "==> Verifica: selector-pvc-gold è legato a selector-pv-gold?" -ForegroundColor Cyan
$boundTo = kubectl get pvc selector-pvc-gold -o jsonpath='{.spec.volumeName}'
if ($boundTo -eq "selector-pv-gold") {
    Write-Host "    [OK] selector-pvc-gold → $boundTo (tier=gold, zone=zone-a)" -ForegroundColor Green
} else {
    Write-Host "    [WARN] selector-pvc-gold è legato a: $boundTo" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> PV gold (tier=gold, zone=zone-a):" -ForegroundColor Green
kubectl get pv selector-pv-gold -o jsonpath=`
    '{"Name:   "}{.metadata.name}{"\nLabels: "}{.metadata.labels}{"\nStatus: "}{.status.phase}{"\n"}'

Write-Host ""
Write-Host "==> PV silver (tier=silver, zone=zone-b):" -ForegroundColor Green
kubectl get pv selector-pv-silver -o jsonpath=`
    '{"Name:   "}{.metadata.name}{"\nLabels: "}{.metadata.labels}{"\nStatus: "}{.status.phase}{"\n"}'

Write-Host ""
Write-Host "==> Binding diretto per nome (named-pvc → named-pv):" -ForegroundColor Cyan
kubectl get pvc named-pvc -o jsonpath='{"PVC: "}{.metadata.name}{" → PV: "}{.spec.volumeName}{"\n"}'

Write-Host ""
Write-Host "==> Confronto tra i tre metodi di selezione PV:" -ForegroundColor Yellow
Write-Host "    1. Automatico (nessun selector):    Kubernetes sceglie il PV più piccolo compatibile"
Write-Host "    2. matchLabels selector:            PVC seleziona PV con label specifiche"
Write-Host "    3. volumeName (binding diretto):    PVC si lega esattamente a quel PV per nome"

Write-Host ""
Write-Host "[OK] Scenario 02 completato." -ForegroundColor Green
