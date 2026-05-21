#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del pattern initContainer + emptyDir.
    L'initContainer prepara il volume; il container principale lo usa.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 05 — initContainer + emptyDir" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply pod (2 initContainer + 1 container app)..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\pod.yaml"

Write-Host ""
Write-Host "==> Sequenza initContainer (devono completarsi prima dell'app):" -ForegroundColor Yellow
Write-Host "    Osserva lo stato: Init:0/2 → Init:1/2 → Init:2/2 → Running"
Start-Sleep -Seconds 3
kubectl get pod init-volume-demo -w &
$watchJob = $null
Start-Sleep -Seconds 15
kubectl wait --for=condition=Ready pod/init-volume-demo --timeout=60s

Write-Host ""
Write-Host "==> Log initContainer 'config-generator':" -ForegroundColor Green
kubectl logs init-volume-demo -c config-generator

Write-Host ""
Write-Host "==> Log initContainer 'permission-fixer':" -ForegroundColor Green
kubectl logs init-volume-demo -c permission-fixer

Write-Host ""
Write-Host "==> Log container 'app' (legge il volume preparato dai init):" -ForegroundColor Green
kubectl logs init-volume-demo -c app

Write-Host ""
Write-Host "==> Struttura volume /app-data/ dall'interno del container app:" -ForegroundColor Cyan
kubectl exec init-volume-demo -c app -- find /app-data -type f | Sort-Object

Write-Host ""
Write-Host "==> Casi d'uso tipici degli initContainer:" -ForegroundColor Yellow
Write-Host "    - Clonare un repo git nel volume"
Write-Host "    - Scaricare asset/binari da un bucket"
Write-Host "    - Attendere che un servizio dipendente sia pronto"
Write-Host "    - Inizializzare un database"
Write-Host "    - Generare certificati o config dinamici"

Write-Host ""
Write-Host "[OK] Scenario 05 completato." -ForegroundColor Green
