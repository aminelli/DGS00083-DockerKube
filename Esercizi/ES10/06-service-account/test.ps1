#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del ServiceAccount con Secret token e RBAC.
.DESCRIPTION
    Dimostra:
      - Token generato automaticamente per il SA (k8s >= 1.24)
      - Token proiettato nel pod
      - Chiamata all'API Kubernetes con il token (operazioni consentite/negate)
      - Token permanente via Secret manuale vs token proiettato temporaneo
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 06 — ServiceAccount + Token Secret + RBAC" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply SA + Secret + Role + RoleBinding..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\serviceaccount.yaml"
Start-Sleep -Seconds 2   # Kubernetes popola il token nel Secret

Write-Host ""
Write-Host "==> Token generato nel Secret (kubernetes.io/service-account-token):" -ForegroundColor Green
$token = kubectl get secret pod-reader-sa-token -o jsonpath='{.data.token}'
if ($token) {
    Write-Host "    Token generato: SI ($($token.Length) chars base64)" -ForegroundColor Green
    $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($token))
    $header  = $decoded.Split('.')[0]
    # Decodifica header JWT (potrebbe necessitare padding)
    $pad = switch ($header.Length % 4) { 2 {"=="} 3 {"="} default {""} }
    $hdrJson = [Convert]::FromBase64String(($header -replace '-','+' -replace '_','/') + $pad)
    $hdrObj  = [Text.Encoding]::UTF8.GetString($hdrJson) | ConvertFrom-Json
    Write-Host "    JWT header: alg=$($hdrObj.alg), typ=$($hdrObj.typ)" -ForegroundColor White
} else {
    Write-Host "    Token non ancora disponibile, attendi qualche secondo." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> Verifica RBAC (can-i):" -ForegroundColor Cyan
$canListPods  = kubectl auth can-i list pods   --as=system:serviceaccount:default:pod-reader-sa
$canDelPods   = kubectl auth can-i delete pods --as=system:serviceaccount:default:pod-reader-sa
$canListDeploy = kubectl auth can-i list deployments --as=system:serviceaccount:default:pod-reader-sa
Write-Host "    list pods:        $canListPods  (atteso: yes)" -ForegroundColor $(if ($canListPods -eq "yes") {"Green"} else {"Red"})
Write-Host "    delete pods:      $canDelPods (atteso: no)"  -ForegroundColor $(if ($canDelPods -eq "no") {"Green"} else {"Red"})
Write-Host "    list deployments: $canListDeploy (atteso: no)" -ForegroundColor $(if ($canListDeploy -eq "no") {"Green"} else {"Red"})

Write-Host ""
Write-Host "==> Deploy Pod che usa il ServiceAccount..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\pod.yaml"
kubectl wait --for=condition=Ready pod/sa-token-demo --timeout=60s

Write-Host ""
Write-Host "==> Log del pod (chiamate API con token del SA):" -ForegroundColor Green
kubectl logs sa-token-demo

Write-Host ""
Write-Host "==> Token permanente vs token proiettato:" -ForegroundColor Yellow
Write-Host "    /var/run/secrets/kubernetes.io/serviceaccount/token = token proiettato (scade)" -ForegroundColor White
Write-Host "    Secret pod-reader-sa-token.data.token               = token permanente" -ForegroundColor White
Write-Host ""
Write-Host "    Token permanente (per CI/CD, decodificato):" -ForegroundColor Cyan
if ($token) {
    $permToken = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($token))
    Write-Host "    Lunghezza: $($permToken.Length) caratteri" -ForegroundColor White
    Write-Host "    (Per usarlo: -H 'Authorization: Bearer $permToken')" -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "[OK] Scenario 06 completato." -ForegroundColor Green
Write-Host "     Pod → SA → RoleBinding → Role → permessi limitati a list/get pods." -ForegroundColor Yellow
