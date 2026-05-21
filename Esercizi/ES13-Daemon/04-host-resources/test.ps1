#Requires -Version 5.1
<#
.SYNOPSIS
    Test del DaemonSet con accesso alle risorse del nodo (hostNetwork, hostPath).
    Simula un agente di monitoring che legge /proc e /var/log del nodo.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 04 — DaemonSet con risorse host (hostNetwork + hostPath)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> Apply DaemonSet node-monitor (hostNetwork=true, hostPath mounts)..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\daemonset.yaml"
kubectl rollout status daemonset/node-monitor --timeout=90s

Write-Host ""
Write-Host "==> Pod del monitor:" -ForegroundColor Green
kubectl get pods -l app=node-monitor -o wide

Write-Host ""
$pod = kubectl get pods -l app=node-monitor -o jsonpath='{.items[0].metadata.name}'
Write-Host "==> [hostNetwork] IP del pod = IP del nodo host:" -ForegroundColor Cyan
$podIP  = kubectl get pod $pod -o jsonpath='{.status.podIP}'
$nodeIP = kubectl get pod $pod -o jsonpath='{.status.hostIP}'
Write-Host "    Pod IP:  $podIP"
Write-Host "    Node IP: $nodeIP"
if ($podIP -eq $nodeIP) {
    Write-Host "    [OK] hostNetwork=true: il pod usa l'IP del nodo." -ForegroundColor Green
} else {
    Write-Host "    Pod IP e Node IP sono diversi (verificare configurazione)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> [hostPath /proc] Dati di sistema del nodo letti dal pod:" -ForegroundColor Cyan
kubectl exec $pod -- cat /host/proc/meminfo 2>$null | Select-Object -First 6 |
    ForEach-Object { Write-Host "    $_" }

Write-Host ""
Write-Host "==> [hostPath /etc] OS del nodo:" -ForegroundColor Cyan
kubectl exec $pod -- cat /host/etc/os-release 2>$null | Select-String "NAME|VERSION" |
    ForEach-Object { Write-Host "    $_" }

Write-Host ""
Write-Host "==> [hostPath /var/log] File di log del nodo visibili nel pod:" -ForegroundColor Cyan
kubectl exec $pod -- ls /host/var/log/ 2>$null | Select-Object -First 10 |
    ForEach-Object { Write-Host "    $_" }

Write-Host ""
Write-Host "==> Log del pod (output dell'agente):" -ForegroundColor Green
kubectl logs $pod | Select-String "Mount|proc|log|interfacce|hostPath" | Select-Object -First 8

Write-Host ""
Write-Host "==> Volumi montati dal pod:" -ForegroundColor Yellow
kubectl get pod $pod -o jsonpath='{range .spec.volumes[*]}  {"name="}{.name}{"  hostPath="}{.hostPath.path}{"\n"}{end}'

Write-Host ""
Write-Host "[OK] Scenario 04 completato." -ForegroundColor Green
Write-Host "     hostNetwork: pod usa rete del nodo  |  hostPath: accede al filesystem del nodo." -ForegroundColor Yellow
