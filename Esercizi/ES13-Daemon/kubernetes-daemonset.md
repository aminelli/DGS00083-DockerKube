# Kubernetes: DaemonSet

## Indice
1. [Cos'è un DaemonSet](#1-cosè-un-daemonset)
2. [DaemonSet vs Deployment vs StatefulSet](#2-daemonset-vs-deployment-vs-statefulset)
3. [Struttura del manifest](#3-struttura-del-manifest)
4. [Placement: nodeSelector e nodeAffinity](#4-placement-nodeselector-e-nodeaffinity)
5. [Tolerations e Taint](#5-tolerations-e-taint)
6. [Accesso alle risorse del nodo host](#6-accesso-alle-risorse-del-nodo-host)
7. [Update Strategies](#7-update-strategies)
8. [Ciclo di vita](#8-ciclo-di-vita)
9. [Pattern comuni in produzione](#9-pattern-comuni-in-produzione)
10. [Comandi utili](#10-comandi-utili)
11. [Scenari del lab](#11-scenari-del-lab)

---

## 1. Cos'è un DaemonSet

Un **DaemonSet** garantisce che un **pod venga eseguito su ogni nodo** del cluster (o su un sottoinsieme definito). Al contrario di un Deployment, non si specifica quante repliche creare: il numero di pod è determinato dal numero di nodi.

**Comportamento automatico**:
- Quando un **nuovo nodo entra** nel cluster → il pod viene schedulato automaticamente
- Quando un **nodo viene rimosso** → il pod viene eliminato automaticamente
- Non è possibile scalare un DaemonSet: il numero di pod = numero di nodi selezionati

**Casi d'uso tipici**:

| Categoria | Esempi |
|-----------|--------|
| Monitoring e metriche | Prometheus node-exporter, Datadog agent, New Relic |
| Raccolta log | Fluentd, Fluent Bit, Filebeat, Vector |
| Plugin di rete | Calico, Flannel, Cilium, WeaveNet |
| Plugin di storage | Ceph/Rook agent, Longhorn manager, OpenEBS |
| Sicurezza | Falco, Sysdig agent, Aqua enforcer |
| Cache | Envoy (service mesh), Istio sidecar injector |

---

## 2. DaemonSet vs Deployment vs StatefulSet

| Caratteristica | Deployment | StatefulSet | DaemonSet |
|---------------|------------|-------------|-----------|
| Numero pod | `replicas` (fisso) | `replicas` (fisso) | = nodi selezionati |
| Placement | Scheduler sceglie | Scheduler sceglie | 1 pod per nodo |
| Nomi pod | Casuali | Ordinali (`app-0`) | `<ds-name>-<hash>` |
| Scaling manuale | Sì | Sì | No (dipende dai nodi) |
| Nuovo nodo | Nessun effetto | Nessun effetto | Pod aggiunto automaticamente |
| Nodo rimosso | Nessun effetto | Nessun effetto | Pod rimosso automaticamente |
| Storage stabile | No | Sì (volumeClaimTemplates) | No (di solito) |
| Identità stabile | No | Sì | No |
| Taint/Toleration | Opzionale | Opzionale | Spesso necessari |

---

## 3. Struttura del manifest

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: my-agent
  namespace: kube-system   # spesso in kube-system per agenti di sistema
spec:
  selector:
    matchLabels:
      app: my-agent

  updateStrategy:
    type: RollingUpdate    # o OnDelete
    rollingUpdate:
      maxUnavailable: 1    # numero o percentuale (es. "10%")

  template:
    metadata:
      labels:
        app: my-agent
    spec:
      terminationGracePeriodSeconds: 30

      # Opzionale: limita ai nodi con questa label
      nodeSelector:
        my-label: "true"

      # Opzionale: per girare su nodi con taint
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule

      containers:
        - name: agent
          image: my-agent:1.0
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName    # nome del nodo corrente
            - name: NODE_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP    # IP del nodo corrente
          resources:
            requests: { cpu: 50m, memory: 64Mi }
            limits:   { cpu: 200m, memory: 256Mi }
          volumeMounts:
            - name: host-logs
              mountPath: /host/var/log
              readOnly: true

      volumes:
        - name: host-logs
          hostPath:
            path: /var/log
```

---

## 4. Placement: nodeSelector e nodeAffinity

Per default il DaemonSet gira su **tutti i nodi**. Si può limitare a un sottoinsieme:

### nodeSelector (semplice)

```yaml
spec:
  template:
    spec:
      nodeSelector:
        disktype: ssd        # solo nodi con questa label
        zone: eu-west-1a
```

```bash
# Aggiunge la label a un nodo
kubectl label node my-node disktype=ssd
# Rimuove la label
kubectl label node my-node disktype-
```

### nodeAffinity (flessibile)

```yaml
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          # DEVE essere soddisfatta (hard requirement)
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: tier
                    operator: In
                    values: [worker, compute]
                  - key: maintenance
                    operator: DoesNotExist   # escludi nodi in manutenzione

          # PREFERIBILE (soft requirement, non blocca lo scheduling)
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: high-memory
                    operator: In
                    values: ["true"]
```

| Operatore | Significato |
|-----------|-------------|
| `In` | label ha uno dei valori specificati |
| `NotIn` | label NON ha nessuno dei valori |
| `Exists` | label esiste (qualsiasi valore) |
| `DoesNotExist` | label non esiste |
| `Gt` / `Lt` | valore numerico maggiore/minore |

---

## 5. Tolerations e Taint

I **taint** impediscono la schedulazione di pod normali su un nodo. Il pod deve dichiarare una **toleration** corrispondente per essere schedulato.

### Taint di sistema (Kubernetes built-in)

| Taint | Applicato da | Significato |
|-------|-------------|-------------|
| `node-role.kubernetes.io/control-plane:NoSchedule` | Admin / kubeadm | Nodo control-plane |
| `node.kubernetes.io/not-ready:NoExecute` | Node controller | Nodo non pronto |
| `node.kubernetes.io/unreachable:NoExecute` | Node controller | Nodo irraggiungibile |
| `node.kubernetes.io/disk-pressure:NoSchedule` | Kubelet | Disco quasi pieno |
| `node.kubernetes.io/memory-pressure:NoSchedule` | Kubelet | Memoria quasi esaurita |
| `node.kubernetes.io/pid-pressure:NoSchedule` | Kubelet | PID esauriti |
| `node.kubernetes.io/unschedulable:NoSchedule` | `kubectl cordon` | Nodo cordoned |

### Toleration per DaemonSet di sistema

```yaml
tolerations:
  # Control-plane (obbligatorio per agenti che devono girare ovunque)
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  # Nodi problematici (utile per agenti di rete/storage/recovery)
  - key: node.kubernetes.io/not-ready
    operator: Exists
    effect: NoExecute
    tolerationSeconds: 300    # evict dopo 5 min di not-ready
  - key: node.kubernetes.io/unreachable
    operator: Exists
    effect: NoExecute
    tolerationSeconds: 300
```

### Taint personalizzati

```bash
# Applica un taint a un nodo
kubectl taint node my-gpu-node gpu=true:NoSchedule

# Rimuovi il taint
kubectl taint node my-gpu-node gpu=true:NoSchedule-
```

### Effetti possibili

| Effect | Comportamento |
|--------|---------------|
| `NoSchedule` | Nuovi pod non schedulati (quelli esistenti rimangono) |
| `PreferNoSchedule` | Preferibilmente non schedulato (soft) |
| `NoExecute` | Pod esistenti evicted + nuovi non schedulati |

---

## 6. Accesso alle risorse del nodo host

I DaemonSet di monitoring e sicurezza spesso accedono alle risorse del nodo:

### hostNetwork

```yaml
spec:
  template:
    spec:
      hostNetwork: true           # usa la rete del nodo (stesso IP, stesse porte)
      dnsPolicy: ClusterFirstWithHostNet   # obbligatorio con hostNetwork: true
```

Con `hostNetwork: true`:
- Il pod usa l'IP del nodo (non un IP del pod)
- Può aprire porte direttamente sul nodo senza NodePort
- Vede tutte le interfacce di rete del nodo

### hostPID / hostIPC

```yaml
spec:
  template:
    spec:
      hostPID: true    # accesso ai processi del nodo (ps ax mostra tutti i proc)
      hostIPC: true    # condivide IPC namespace (semafori, shared memory)
```

### hostPath (montare directory del nodo)

```yaml
volumeMounts:
  - name: host-proc
    mountPath: /host/proc
    readOnly: true
  - name: host-logs
    mountPath: /host/var/log
    readOnly: true

volumes:
  - name: host-proc
    hostPath:
      path: /proc
      type: Directory
  - name: host-logs
    hostPath:
      path: /var/log
      type: DirectoryOrCreate
```

### Downward API per info nodo

```yaml
env:
  - name: NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName      # es. k8s-worker-1
  - name: NODE_IP
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP      # IP del nodo host
```

---

## 7. Update Strategies

### RollingUpdate (default)

Aggiorna un nodo alla volta (o `maxUnavailable` nodi contemporaneamente):

```yaml
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1     # numero o percentuale (es. "10%")
    # maxSurge: 0         # (k8s >= 1.22) pod extra durante l'update
```

**Comportamento**: per ogni nodo, il pod vecchio viene terminato → pod nuovo avviato. Con `maxUnavailable: 1` c'è sempre al massimo 1 nodo senza agente.

### OnDelete

```yaml
updateStrategy:
  type: OnDelete
```

Il pod viene aggiornato **solo quando viene eliminato manualmente**. Utile per:
- Aggiornamenti che richiedono `kubectl drain` preventivo
- Ambienti con finestre di manutenzione rigide
- Cluster con nodi specializzati che non devono essere interrotti automaticamente

```bash
# Aggiorna un nodo specifico con OnDelete
kubectl drain my-node --ignore-daemonsets
kubectl delete pod my-ds-pod-xxxx      # ricreato con nuovo template
kubectl uncordon my-node
```

### Rollback

```bash
kubectl rollout undo daemonset/my-agent
kubectl rollout history daemonset/my-agent
kubectl rollout undo daemonset/my-agent --to-revision=2
```

---

## 8. Ciclo di vita

```
Cluster con 3 nodi
  → DaemonSet creato → 3 pod creati (1 per nodo)

Nodo 4 aggiunto al cluster
  → Pod 4 schedulato automaticamente (nessun intervento manuale)

Nodo 2 rimosso dal cluster
  → Pod 2 eliminato automaticamente

kubectl label node-3 disktype=ssd
  → DaemonSet con nodeSelector disktype=ssd ora gira su node-3
  → I pod sugli altri nodi vengono eliminati

kubectl taint node-1 special=true:NoSchedule
  → Se il DaemonSet non ha toleration per special:NoSchedule
    → pod su node-1 viene evicted (se NoExecute) o rimane (se NoSchedule)

DaemonSet eliminato
  → Tutti i pod vengono eliminati
```

---

## 9. Pattern comuni in produzione

### Log collector (Fluentd/Filebeat)

```
DaemonSet log-collector
  ├── Tolera tutti i taint (anche nodi problematici)
  ├── priorityClassName: system-node-critical
  ├── hostPath /var/log/pods → legge log di tutti i container
  ├── hostPath /var/log      → legge log di sistema
  └── Output → Elasticsearch / Loki / Splunk
```

### Node exporter (Prometheus)

```
DaemonSet prometheus-node-exporter
  ├── hostNetwork: true      (metrics sulla porta 9100 del nodo)
  ├── hostPID: true          (metriche sui processi del nodo)
  ├── hostPath /proc /sys    (metriche hardware e kernel)
  └── Prometheus scrapes → porta 9100 di ogni nodo
```

### CNI plugin (Calico/Cilium)

```
DaemonSet calico-node
  ├── Tolera TUTTO (deve girare su ogni nodo fin dal boot)
  ├── hostNetwork: true
  ├── hostPath /etc/cni/net.d  (installa plugin CNI sul nodo)
  ├── initContainer installa binari CNI
  └── priorityClassName: system-node-critical
```

---

## 10. Comandi utili

```bash
# Lista DaemonSet
kubectl get daemonsets
kubectl get ds              # abbreviazione

# Stato con numero pod desiderati/pronti
kubectl get ds my-agent
# DESIRED = nodi selezionati
# CURRENT = pod creati
# READY   = pod in Ready
# UP-TO-DATE = pod con il template aggiornato
# AVAILABLE  = pod disponibili

# Dettaglio (include update strategy, selectors, tolerations)
kubectl describe ds my-agent

# Pod di un DaemonSet e su quali nodi girano
kubectl get pods -l app=my-agent -o wide

# Rollout status
kubectl rollout status daemonset/my-agent

# Aggiorna l'immagine (triggera RollingUpdate)
kubectl set image daemonset/my-agent agent=my-agent:2.0

# Rollback
kubectl rollout undo daemonset/my-agent

# Cronologia revisioni
kubectl rollout history daemonset/my-agent

# Pausa e riprendi un rollout
kubectl rollout pause daemonset/my-agent
kubectl rollout resume daemonset/my-agent

# Applica taint a un nodo
kubectl taint node my-node key=value:NoSchedule
# Rimuovi taint
kubectl taint node my-node key=value:NoSchedule-

# Label su un nodo (per nodeSelector)
kubectl label node my-node disktype=ssd
# Rimuovi label
kubectl label node my-node disktype-

# Exec in un pod DaemonSet su un nodo specifico
NODE="my-node"
POD=$(kubectl get pods -l app=my-agent --field-selector spec.nodeName=$NODE -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD -- bash

# PowerShell: mappa pod → nodo
kubectl get pods -l app=my-agent -o jsonpath='{range .items[*]}{.metadata.name}{"  →  "}{.spec.nodeName}{"\n"}{end}'
```

---

## 11. Scenari del lab

| # | Cartella | Scenario | Concetti chiave |
|---|----------|----------|-----------------|
| 01 | `01-basic/` | DaemonSet su tutti i nodi | DESIRED=nodi, nomi auto, downwardAPI NODE_NAME |
| 02 | `02-node-selector/` | nodeSelector e nodeAffinity | Label sui nodi, matchExpressions |
| 03 | `03-tolerations/` | Toleration per control-plane | Taint NoSchedule, NoExecute, tolerationSeconds |
| 04 | `04-host-resources/` | hostNetwork + hostPath | IP nodo, /proc, /var/log, /etc del nodo |
| 05 | `05-update-strategy/` | RollingUpdate e OnDelete | maxUnavailable, aggiornamento manuale |
| 06 | `06-log-collector/` | Pattern log collector | Fluentd/Filebeat pattern, ConfigMap script |

### Esecuzione rapida

```powershell
# Tutti gli scenari
.\00-deploy-all.ps1

# Solo scenario specifico
.\00-deploy-all.ps1 -Scenario 4

# Cleanup completo
.\99-cleanup-all.ps1
```

### Prerequisiti

- Kind cluster attivo: `kubectl cluster-info`
- Immagini: `busybox:1.36`, `nginx:1.25-alpine`
- Scenario 06: `system-node-critical` PriorityClass (presente di default in Kind)

---

## Appendice: DaemonSet vs altri controller

```
Hai bisogno che ogni nodo abbia esattamente 1 pod?
  → DaemonSet

Il numero di pod è fisso e lo scheduler decide il nodo?
  → Deployment

I pod hanno identità stabile e storage dedicato?
  → StatefulSet

Il pod deve completare un'elaborazione e terminare?
  → Job / CronJob
```

---

*Documentazione generata per il lab `k8s-daemonset-examples` — Kind + Docker Desktop.*
