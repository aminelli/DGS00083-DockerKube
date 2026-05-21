#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del Docker Registry pull Secret.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 05 — Docker Registry pull Secret" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply Secret + Pod (immagine pubblica per il demo)..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\secret.yaml"
kubectl apply -f "$ScriptDir\pod.yaml"
kubectl wait --for=condition=Ready pod/registry-pull-demo --timeout=90s

Write-Host ""
Write-Host "==> Tipo del Secret: kubernetes.io/dockerconfigjson" -ForegroundColor Green
kubectl get secret registry-credentials -o wide

Write-Host ""
Write-Host "==> Struttura .dockerconfigjson (la password è offuscata qui):" -ForegroundColor Cyan
$raw = kubectl get secret registry-credentials -o jsonpath='{.data.\.dockerconfigjson}'
$decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($raw))
$json = $decoded | ConvertFrom-Json
$json.auths.PSObject.Properties | ForEach-Object {
    Write-Host "    Registry: $($_.Name)"
    Write-Host "    Username: $($_.Value.username)"
    Write-Host "    Password: <HIDDEN ($($_.Value.password.Length) chars)>"
}

Write-Host ""
Write-Host "==> Log pod (usa imagePullSecrets correttamente configurato):" -ForegroundColor Green
kubectl logs registry-pull-demo

Write-Host ""
Write-Host "==> Aggiungere il pull secret a un ServiceAccount (pattern prod):" -ForegroundColor Yellow
Write-Host "    Cosi' tutti i pod che usano il SA ereditano il pull secret automaticamente:" -ForegroundColor White
Write-Host @"

    kubectl patch serviceaccount default -p '{
      "imagePullSecrets": [{"name": "registry-credentials"}]
    }'

    # Oppure nel YAML del ServiceAccount:
    imagePullSecrets:
      - name: registry-credentials
"@ -ForegroundColor DarkYellow

Write-Host ""
Write-Host "==> Creazione pull secret imperativa (per CI/CD pipeline):" -ForegroundColor Yellow
Write-Host @"
    kubectl create secret docker-registry registry-credentials \
      --docker-server=registry.example.com \
      --docker-username=ci-user \
      --docker-password=`$TOKEN \
      --docker-email=ci@example.com
"@ -ForegroundColor DarkYellow

Write-Host ""
Write-Host "[OK] Scenario 05 completato." -ForegroundColor Green
