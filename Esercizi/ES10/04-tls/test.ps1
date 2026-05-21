#Requires -Version 5.1
<#
.SYNOPSIS
    Genera un TLS Secret e ne mostra la struttura e le proprietà del certificato.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 04 — TLS Secret (kubernetes.io/tls)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> [1/3] Generazione certificato self-signed..." -ForegroundColor Cyan
& "$ScriptDir\gen-tls-secret.ps1"

Write-Host ""
Write-Host "==> [2/3] Struttura del Secret TLS:" -ForegroundColor Green
kubectl get secret tls-demo-cert -o yaml |
    Select-String -Pattern "type|tls.crt|tls.key|creationTimestamp"

Write-Host ""
Write-Host "==> Il Secret TLS ha esattamente due chiavi: tls.crt e tls.key" -ForegroundColor Cyan
kubectl get secret tls-demo-cert -o jsonpath='{range .data}{@}{"\n"}{end}'

Write-Host ""
Write-Host "==> [3/3] Dettagli del certificato (decodifica tls.crt):" -ForegroundColor Cyan
$b64cert = kubectl get secret tls-demo-cert -o jsonpath='{.data.tls\.crt}'
$certBytes = [Convert]::FromBase64String($b64cert)
$certPem   = [Text.Encoding]::ASCII.GetString($certBytes)
$certPem | Out-File -FilePath "$env:TEMP\demo-cert.pem" -Encoding ASCII

if (Get-Command openssl -ErrorAction SilentlyContinue) {
    openssl x509 -in "$env:TEMP\demo-cert.pem" -noout -text |
        Select-String -Pattern "Subject:|Issuer:|Not Before|Not After|DNS:" -Context 0,0
    Remove-Item "$env:TEMP\demo-cert.pem" -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "==> Uso tipico: Ingress con TLS (da k8s-ingress-examples scenario 04):" -ForegroundColor Yellow
Write-Host @"
    spec:
      tls:
        - hosts:
            - secure.local
          secretName: tls-demo-cert    # questo Secret
      rules: ...
"@ -ForegroundColor DarkYellow

Write-Host ""
Write-Host "==> Scadenza certificato (importante da monitorare!):" -ForegroundColor Cyan
if (Get-Command openssl -ErrorAction SilentlyContinue) {
    $b64cert = kubectl get secret tls-demo-cert -o jsonpath='{.data.tls\.crt}'
    [Convert]::FromBase64String($b64cert) |
        Set-Content "$env:TEMP\demo-cert.pem" -AsByteStream
    openssl x509 -in "$env:TEMP\demo-cert.pem" -noout -enddate
    Remove-Item "$env:TEMP\demo-cert.pem" -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "[OK] Scenario 04 completato." -ForegroundColor Green
Write-Host "     In produzione usa cert-manager per rinnovo automatico." -ForegroundColor Yellow
