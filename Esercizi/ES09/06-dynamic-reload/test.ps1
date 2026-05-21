#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del ConfigMap con dynamic reload (aggiornamento a runtime).
.DESCRIPTION
    Dimostra che i file montati via Volume (senza subPath) vengono aggiornati
    automaticamente quando il ConfigMap cambia.
    Tempo di propagazione: entro il kubelet configMapAndSecretChangeDetectionStrategy
    (default: ~60s, oppure istantaneo con triggerBasedAcknowledge).
#>
$ErrorActionPreference = "Stop"
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$LOCAL_PORT = 8090

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 06 — Dynamic reload (volume mount)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply ConfigMap + Deployment + Service..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\configmap.yaml"
kubectl apply -f "$ScriptDir\deployment.yaml"
kubectl wait --for=condition=available deployment/webpage-server --timeout=60s

$POD = kubectl get pod -l app=webpage-server -o jsonpath='{.items[0].metadata.name}'
Write-Host "    Pod: $POD" -ForegroundColor White

# ── Contenuto iniziale ─────────────────────────────────────────
Write-Host ""
Write-Host "==> [1/4] Contenuto iniziale (v1) via exec:" -ForegroundColor Cyan
kubectl exec $POD -- cat /usr/share/nginx/html/index.html | Select-String "Versione|version"

Write-Host ""
Write-Host "==> [1/4] Contenuto config.json:" -ForegroundColor Cyan
kubectl exec $POD -- cat /usr/share/nginx/html/config.json

# Port-forward per test HTTP
$pf = Start-Job -ScriptBlock {
    param($p)
    kubectl port-forward svc/webpage-svc "${p}:80" 2>&1
} -ArgumentList $LOCAL_PORT
Start-Sleep -Seconds 2

try {
    Write-Host ""
    Write-Host "==> [1/4] Risposta HTTP (atteso v1):" -ForegroundColor Cyan
    curl.exe -s "http://localhost:$LOCAL_PORT/" | Select-String "Versione|v1|originale"

    # ── Patch del ConfigMap ────────────────────────────────────
    Write-Host ""
    Write-Host "==> [2/4] Patch del ConfigMap (aggiornamento a v2)..." -ForegroundColor Yellow

    $newHtml = @'
<!DOCTYPE html>
<html>
<head><title>Dynamic Reload - v2</title></head>
<body style="font-family:sans-serif;padding:2rem;background:#c8e6c9">
  <h1>&#128257; ConfigMap Dynamic Reload</h1>
  <p><strong>Versione:</strong> <code>v2</code> — AGGIORNATA senza riavvio pod!</p>
  <p>Il file e'' stato aggiornato automaticamente dal kubelet dopo il patch del ConfigMap.</p>
</body>
</html>
'@
    # Escape per JSON patch
    $escaped = $newHtml -replace '"', '\"' -replace "`n", '\n' -replace "`r", ''
    $patch = "{`"data`":{`"index.html`":`"$escaped`",`"config.json`":`"{`\`"version`\`":`\`"2`\`",`\`"feature_flags`\`":{`\`"dark_mode`\`":true}}`\n`"}}"

    # Usa kubectl create/replace per semplicita' con contenuto multi-riga
    kubectl create configmap webpage-content `
        --from-literal="index.html=$newHtml" `
        --from-literal='config.json={"version":"2","feature_flags":{"dark_mode":true}}' `
        --dry-run=client -o yaml | kubectl apply -f -

    Write-Host "    ConfigMap aggiornato. Attesa propagazione kubelet..." -ForegroundColor Yellow
    Write-Host "    (La propagazione richiede fino a ~60s con Kind)" -ForegroundColor DarkYellow

    # ── Attesa e verifica ─────────────────────────────────────
    Write-Host ""
    Write-Host "==> [3/4] Verifica propagazione (polling ogni 10s, max 90s)..." -ForegroundColor Cyan
    $elapsed = 0
    $updated = $false
    while ($elapsed -lt 90) {
        Start-Sleep -Seconds 10
        $elapsed += 10
        $content = kubectl exec $POD -- cat /usr/share/nginx/html/index.html 2>&1
        if ($content -match "v2|AGGIORNATA") {
            $updated = $true
            Write-Host "    [OK] File aggiornato dopo ${elapsed}s!" -ForegroundColor Green
            break
        }
        Write-Host "    ${elapsed}s: ancora v1..." -ForegroundColor Yellow
    }

    if (-not $updated) {
        Write-Host "    [!] File non ancora aggiornato dopo 90s." -ForegroundColor Red
        Write-Host "    Prova: kubectl exec $POD -- cat /usr/share/nginx/html/index.html" -ForegroundColor DarkYellow
    }

    # ── Test HTTP post-aggiornamento ──────────────────────────
    Write-Host ""
    Write-Host "==> [4/4] Risposta HTTP dopo aggiornamento:" -ForegroundColor Cyan
    curl.exe -s "http://localhost:$LOCAL_PORT/" | Select-String "Versione|v2|AGGIORNATA"

    Write-Host ""
    Write-Host "==> config.json aggiornato:" -ForegroundColor Cyan
    kubectl exec $POD -- cat /usr/share/nginx/html/config.json

} finally {
    $pf | Stop-Job; $pf | Remove-Job -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "[OK] Scenario 06 completato." -ForegroundColor Green
Write-Host "     Il volume mount senza subPath aggiorna i file automaticamente." -ForegroundColor Yellow
Write-Host "     Le applicazioni che leggono i file ad ogni richiesta vedono subito i cambiamenti." -ForegroundColor Yellow
