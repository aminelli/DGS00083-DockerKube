#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test di nginx con configurazione da ConfigMap (subPath mount).
.DESCRIPTION
    Verifica:
      - Header HTTP di sicurezza aggiunti dal ConfigMap default.conf
      - Endpoint /health e /info definiti nella config
      - Pagina index.html servita dal ConfigMap
#>
$ErrorActionPreference = "Stop"
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$LOCAL_PORT = 8089

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 04 — nginx config da ConfigMap" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply ConfigMap + Deployment + Service..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\configmap.yaml"
kubectl apply -f "$ScriptDir\deployment.yaml"
kubectl wait --for=condition=available deployment/nginx-custom --timeout=60s

Write-Host ""
Write-Host "==> File montati nel container (subPath):" -ForegroundColor Cyan
$POD = kubectl get pod -l app=nginx-custom -o jsonpath='{.items[0].metadata.name}'
kubectl exec $POD -- sh -c "nginx -T 2>/dev/null | grep -E 'add_header|location|return' | head -20"

# Port-forward
Write-Host ""
Write-Host "==> Avvio port-forward su porta $LOCAL_PORT..." -ForegroundColor Cyan
$pf = Start-Job -ScriptBlock {
    param($p)
    kubectl port-forward svc/nginx-custom-svc "${p}:80" 2>&1
} -ArgumentList $LOCAL_PORT
Start-Sleep -Seconds 3

try {
    Write-Host ""
    Write-Host "==> Test homepage (HTTP 200 atteso):" -ForegroundColor Cyan
    $s = curl.exe -s -o NUL -w "%{http_code}" "http://localhost:$LOCAL_PORT/"
    Write-Host "    Status: $s" -ForegroundColor $(if ($s -eq "200") {"Green"} else {"Red"})

    Write-Host ""
    Write-Host "==> Header HTTP di sicurezza (dal ConfigMap):" -ForegroundColor Green
    curl.exe -sI "http://localhost:$LOCAL_PORT/" |
        Select-String -Pattern "X-Frame|X-XSS|X-Content|X-Powered|Cache-Control"

    Write-Host ""
    Write-Host "==> Endpoint /health:" -ForegroundColor Cyan
    $health = curl.exe -s "http://localhost:$LOCAL_PORT/health"
    Write-Host "    Risposta: $health" -ForegroundColor $(if ($health -match "healthy") {"Green"} else {"Yellow"})

    Write-Host ""
    Write-Host "==> Endpoint /info:" -ForegroundColor Cyan
    $info = curl.exe -s "http://localhost:$LOCAL_PORT/info"
    Write-Host "    Risposta: $info" -ForegroundColor White

    Write-Host ""
    Write-Host "==> Contenuto index.html (dal ConfigMap):" -ForegroundColor Green
    curl.exe -s "http://localhost:$LOCAL_PORT/" | Select-String "ConfigMap|nginx"
} finally {
    $pf | Stop-Job; $pf | Remove-Job -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "[OK] Scenario 04 completato." -ForegroundColor Green
Write-Host "     Gli header X-Frame-Options, X-XSS-Protection, X-Powered-By" -ForegroundColor Yellow
Write-Host "     provengono dal ConfigMap 'nginx-custom-config'." -ForegroundColor Yellow
