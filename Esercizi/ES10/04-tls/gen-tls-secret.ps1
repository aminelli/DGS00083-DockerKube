#Requires -Version 5.1
<#
.SYNOPSIS
    Genera un certificato TLS self-signed e crea il Secret kubernetes.io/tls.
    Identico all'helper del modulo Ingress, riutilizzabile indipendentemente.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$HOSTNAME  = "secure.local"
$SECRET    = "tls-demo-cert"
$CERT_FILE = "$ScriptDir\tls.crt"
$KEY_FILE  = "$ScriptDir\tls.key"

Write-Host ""
Write-Host "==> Generazione certificato self-signed per '$HOSTNAME'..." -ForegroundColor Cyan

if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    Write-Error @"
openssl non trovato nel PATH.
  - Git for Windows include openssl:  https://git-scm.com/download/win
  - Chocolatey:  choco install openssl
  - Winget:      winget install -e --id ShiningLight.OpenSSL.Light
"@
    exit 1
}

openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
    -keyout $KEY_FILE `
    -out    $CERT_FILE `
    -subj   "/CN=$HOSTNAME/O=KubeDemoLab" `
    -addext "subjectAltName=DNS:$HOSTNAME"

Write-Host ""
Write-Host "==> Fingerprint:" -ForegroundColor Green
openssl x509 -in $CERT_FILE -noout -fingerprint -subject -dates

Write-Host ""
Write-Host "==> Creazione Secret '$SECRET' (tipo kubernetes.io/tls)..." -ForegroundColor Cyan
kubectl create secret tls $SECRET `
    --cert=$CERT_FILE `
    --key=$KEY_FILE `
    --dry-run=client -o yaml | kubectl apply -f -

Remove-Item $CERT_FILE, $KEY_FILE -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==> Secret creato:" -ForegroundColor Green
kubectl get secret $SECRET -o wide
Write-Host ""
Write-Host "[OK] TLS Secret '$SECRET' pronto." -ForegroundColor Green
