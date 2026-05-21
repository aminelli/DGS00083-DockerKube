#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy e test dell'espansione online di un PVC.
    Dimostra kubectl patch pvc per aumentare la dimensione richiesta.
#>
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "  SCENARIO 06 — Volume Expansion (resize PVC)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "==> [1/4] Apply StorageClass (allowVolumeExpansion: true) + PVC + Deployment..." -ForegroundColor Cyan
kubectl apply -f "$ScriptDir\sc-pvc-deployment.yaml"

Write-Host ""
Write-Host "==> StorageClass expandable-storage:" -ForegroundColor Green
kubectl get storageclass expandable-storage -o jsonpath=`
    '{"Name:                  "}{.metadata.name}{"\nProvisioner:           "}{.provisioner}{"\nReclaimPolicy:         "}{.reclaimPolicy}{"\nallowVolumeExpansion:  "}{.allowVolumeExpansion}{"\n"}'

Write-Host ""
Write-Host "==> Attendo Deployment ready..." -ForegroundColor Yellow
kubectl wait --for=condition=available deployment/expansion-app --timeout=120s

Write-Host ""
Write-Host "==> [2/4] Dimensione PVC prima dell'espansione:" -ForegroundColor Cyan
kubectl get pvc expandable-pvc -o jsonpath=`
    '{"Richiesta:   "}{.spec.resources.requests.storage}{"\nCapacità PV: "}{.status.capacity.storage}{"\nPhase:       "}{.status.phase}{"\n"}'

Write-Host ""
Write-Host "==> [3/4] ESPANSIONE: patch PVC da 50Mi a 200Mi..." -ForegroundColor Green
kubectl patch pvc expandable-pvc --type=merge `
    -p '{"spec":{"resources":{"requests":{"storage":"200Mi"}}}}'

Write-Host ""
Write-Host "==> Condizione di espansione (FileSystemResizePending o già completata):" -ForegroundColor Cyan
Start-Sleep -Seconds 5
kubectl get pvc expandable-pvc -o jsonpath=`
    '{"Richiesta nuova:  "}{.spec.resources.requests.storage}{"\nCapacità attuale:  "}{.status.capacity.storage}{"\nCondizioni:        "}{.status.conditions[*].type}{"\n"}'

Write-Host ""
Write-Host "==> [4/4] Dimensione dopo espansione:" -ForegroundColor Green
Start-Sleep -Seconds 10
kubectl get pvc expandable-pvc -o custom-columns=`
    "PVC:.metadata.name,REQUESTED:.spec.resources.requests.storage,CAPACITY:.status.capacity.storage,STATUS:.status.phase"

Write-Host ""
Write-Host "==> Log del pod (uso disco):" -ForegroundColor Cyan
$pod = kubectl get pod -l app=expansion-app -o jsonpath='{.items[0].metadata.name}'
kubectl logs $pod | Select-String "df|Dimensione|Uso disco|fill"

Write-Host ""
Write-Host "==> Note importanti sull'espansione:" -ForegroundColor Yellow
Write-Host "    ✓ Funziona SOLO se StorageClass.allowVolumeExpansion = true"
Write-Host "    ✓ Si può solo AUMENTARE la dimensione (mai ridurre)"
Write-Host "    ✓ Richiede il pod Running per espansione del filesystem (online resize)"
Write-Host "    ✓ Con hostPath: la capacità riportata aumenta, ma hostPath non ha limiti reali"
Write-Host "    ✓ Con cloud storage (EBS, PD): il disco viene effettivamente esteso"
Write-Host "    ✗ Non si può ridimensionare un PVC (immutable minSize)"

Write-Host ""
Write-Host "[OK] Scenario 06 completato." -ForegroundColor Green
