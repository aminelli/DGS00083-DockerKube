#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del Job one-shot (semplice).
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO: Job One-Shot (semplice)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply Job..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\job.yaml"

Write-Host ""
Write-Host "==> Attesa completamento Job (timeout 120s)..." -ForegroundColor Cyan
kubectl wait --for=condition=complete job/job-simple --timeout=120s

Write-Host ""
Write-Host "==> Stato Job:" -ForegroundColor Green
kubectl get job job-simple -o wide

Write-Host ""
Write-Host "==> Log del Pod:" -ForegroundColor Green
kubectl logs job/job-simple

Write-Host ""
Write-Host "[OK] Job one-shot completato." -ForegroundColor Green
Write-Host "     Il Job verrà auto-eliminato dopo 300s (ttlSecondsAfterFinished)." -ForegroundColor Yellow
