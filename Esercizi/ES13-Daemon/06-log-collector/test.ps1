#Requires -Version 5.1
<#
.SYNOPSIS
    Test del Log Collector DaemonSet: raccolta log da /var/log/pods del nodo.
    Simula il pattern usato da Fluentd, Filebeat, Fluent Bit.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 06 — Log Collector (pattern Fluentd/Filebeat)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply ConfigMap + DaemonSet log-collector..." -ForegroundColor Cyan
# Rimuovi priorityClassName se non disponibile in Kind
kubectl apply -f "$ScriptDir\daemonset.yaml" 2>&1 | ForEach-Object {
    if ($_ -match "no PriorityClass named") {
        Write-Host "    [INFO] PriorityClass non disponibile, rimuovo e riapplico..." -ForegroundColor Yellow
        $yaml = Get-Content "$ScriptDir\daemonset.yaml" -Raw
        $yaml = $yaml -replace '\s*priorityClassName:.*\n', ''
        $yaml | kubectl apply -f - 2>&1 | Out-Null
    } else {
        Write-Host "    $_"
    }
}

kubectl rollout status daemonset/log-collector --timeout=90s

Write-Host ""
Write-Host "==> Pod del collector (uno per nodo):" -ForegroundColor Green
kubectl get pods -l app=log-collector -o wide

Write-Host ""
$pod = kubectl get pods -l app=log-collector -o jsonpath='{.items[0].metadata.name}'
Write-Host "==> Log del collector (avvio e discovery dei log del nodo):" -ForegroundColor Cyan
kubectl logs $pod | Select-Object -First 20

Write-Host ""
Write-Host "==> File di log dei pod trovati sul nodo:" -ForegroundColor Green
kubectl exec $pod -- find /host/var/log/pods -name "*.log" 2>$null |
    Select-Object -First 10 | ForEach-Object { Write-Host "    $_" }

Write-Host ""
Write-Host "==> Output aggregato prodotto dal collector:" -ForegroundColor Cyan
kubectl exec $pod -- cat /collector-data/collected.log 2>$null |
    Select-Object -First 15 | ForEach-Object { Write-Host "    $_" }

Write-Host ""
Write-Host "==> Configurazione simulata (agent.conf):" -ForegroundColor Yellow
kubectl exec $pod -- cat /config/agent.conf 2>$null |
    ForEach-Object { Write-Host "    $_" }

Write-Host ""
Write-Host "==> Volumi montati (pattern realistico):" -ForegroundColor Cyan
kubectl get pod $pod -o jsonpath='{range .spec.volumes[*]}  {.name}: {.hostPath.path}{"\n"}{end}'

Write-Host ""
Write-Host "==> In produzione questo DaemonSet sarebbe sostituito da:" -ForegroundColor Yellow
Write-Host "    - Fluent Bit (leggero, Go, <1MB RAM)"
Write-Host "    - Fluentd    (flessibile, Ruby, molti plugin)"
Write-Host "    - Filebeat   (Elastic, integrazione Kibana)"
Write-Host "    - Vector     (Rust, alte performance)"
Write-Host "    - OpenTelemetry Collector (standard OTEL)"

Write-Host ""
Write-Host "[OK] Scenario 06 completato." -ForegroundColor Green
