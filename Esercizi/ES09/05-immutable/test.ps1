#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test del ConfigMap immutabile.
.DESCRIPTION
    Dimostra:
      - Creazione ConfigMap con immutable: true
      - Lettura dei valori dal pod
      - Tentativo di modifica (rifiutato dall'API server)
      - Pattern di aggiornamento: delete + recreate
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 05 — ConfigMap immutabile" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply ConfigMap + Pod..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\configmap.yaml"
kubectl apply -f "$ScriptDir\pod.yaml"
kubectl wait --for=condition=Ready pod/immutable-reader --timeout=60s

Write-Host ""
Write-Host "==> ConfigMap con immutable: true:" -ForegroundColor Green
kubectl get configmap release-config-v1 -o yaml | Select-String -Pattern "immutable|BUILD_|API_|REGION|FEATURE"

Write-Host ""
Write-Host "==> Log del pod (valori letti):" -ForegroundColor Green
kubectl logs immutable-reader

Write-Host ""
Write-Host "==> [TEST] Tentativo modifica ConfigMap immutabile (atteso errore):" -ForegroundColor Cyan
$patchResult = kubectl patch configmap release-config-v1 `
    --patch '{"data":{"API_VERSION":"v3"}}' 2>&1
if ($patchResult -match "immutable|forbidden" -or $LASTEXITCODE -ne 0) {
    Write-Host "    [OK] Modifica rifiutata: $patchResult" -ForegroundColor Green
} else {
    Write-Host "    Risultato inatteso: $patchResult" -ForegroundColor Red
}

Write-Host ""
Write-Host "==> [TEST] Tentativo annotazione su CM immutabile:" -ForegroundColor Cyan
$annotResult = kubectl annotate configmap release-config-v1 test=value 2>&1
if ($annotResult -match "immutable|forbidden" -or $LASTEXITCODE -ne 0) {
    Write-Host "    [OK] Annotazione rifiutata (il CM e' davvero immutabile)" -ForegroundColor Green
} else {
    Write-Host "    Annotazione aggiunta (le annotazioni non sono dati, possono cambiare)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> Pattern di aggiornamento (non eseguito):" -ForegroundColor Yellow
Write-Host "    Per 'aggiornare' un CM immutabile:" -ForegroundColor White
Write-Host "    1. Crea release-config-v2 con i nuovi valori" -ForegroundColor White
Write-Host "    2. Aggiorna i Deployment per puntare a release-config-v2" -ForegroundColor White
Write-Host "    3. Elimina release-config-v1 quando non e' piu' referenziato" -ForegroundColor White
Write-Host ""
Write-Host "    kubectl delete configmap release-config-v1  # solo se non usato" -ForegroundColor DarkYellow

Write-Host ""
Write-Host "[OK] Scenario 05 completato." -ForegroundColor Green
