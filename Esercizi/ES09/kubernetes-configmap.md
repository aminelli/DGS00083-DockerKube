# Kubernetes ConfigMap

## Indice

1. [Cos'è un ConfigMap](#1-cosè-un-configmap)
2. [ConfigMap vs Secret](#2-configmap-vs-secret)
3. [Creare un ConfigMap](#3-creare-un-configmap)
4. [Modalità di consumo](#4-modalità-di-consumo)
5. [Variabili d'ambiente singole (valueFrom)](#5-variabili-dambiente-singole-valuefrom)
6. [Import massivo (envFrom)](#6-import-massivo-envfrom)
7. [Volume mount: file di configurazione](#7-volume-mount-file-di-configurazione)
8. [subPath: mount di un singolo file](#8-subpath-mount-di-un-singolo-file)
9. [ConfigMap immutabili](#9-configmap-immutabili)
10. [Dynamic reload](#10-dynamic-reload)
11. [Limiti e best practice](#11-limiti-e-best-practice)
12. [Comandi utili](#12-comandi-utili)
13. [Scenari di questo lab](#13-scenari-di-questo-lab)

---

## 1. Cos'è un ConfigMap

Un **ConfigMap** è un oggetto Kubernetes che permette di separare i **dati di configurazione** dall'immagine del container, rendendo le applicazioni portabili tra ambienti diversi (dev, staging, prod) senza dover ricostruire le immagini.

```
senza ConfigMap:                     con ConfigMap:
┌─────────────────────────┐          ┌──────────────┐     ┌─────────────────┐
│  Immagine Docker        │          │  Immagine    │     │  ConfigMap      │
│  ┌───────────────────┐  │          │  (generica)  │ ←── │  DB_HOST=...    │
│  │  config.json con  │  │          │              │     │  LOG_LEVEL=...  │
│  │  DB_HOST=prod      │  │          └──────────────┘     └─────────────────┘
│  │  LOG_LEVEL=info    │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

### Quando usare un ConfigMap

- Stringhe di configurazione (URL, hostname, porte, timeout)
- Feature flags
- File di configurazione (nginx.conf, app.properties, logging.yaml)
- Script di entrypoint
- Qualsiasi configurazione che cambia tra ambienti

### Cosa NON mettere in un ConfigMap

- Password, token, chiavi API → usa un **Secret**
- Dati binari di grandi dimensioni → usa un Volume persistente
- Configurazioni che cambiano frequentemente a runtime → considera un sistema di config distribuita (etcd, Consul, AWS AppConfig)

---

## 2. ConfigMap vs Secret

| Caratteristica           | ConfigMap                    | Secret                                   |
|--------------------------|------------------------------|------------------------------------------|
| Scopo                    | Configurazione non sensibile | Credenziali, chiavi, certificati         |
| Encoding                 | Testo plain (UTF-8)          | Base64 (non è encryption!)               |
| Encryption at rest       | No (default)                 | Sì (se abilitato con EncryptionConfig)   |
| RBAC                     | Standard                     | Può essere ristretto più strettamente    |
| Quota                    | 1 MiB per ConfigMap          | 1 MiB per Secret                         |
| Audit log                | Standard                     | Log separati in molti provider cloud     |

> Un Secret in base64 **non è cifrato**: chiunque abbia accesso RBAC al namespace può leggerlo in chiaro con `kubectl get secret -o yaml`. Usa vault o encryption provider per vera cifratura.

---

## 3. Creare un ConfigMap

### Da YAML (dichiarativo — consigliato)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
  namespace: default
data:
  # Valori semplici (key: value)
  DATABASE_HOST: "postgres.svc.cluster.local"
  DATABASE_PORT: "5432"
  LOG_LEVEL: "info"

  # File completi (valore multi-riga con |)
  app.properties: |
    server.port=8080
    server.context=/app
    cache.ttl=300

  nginx.conf: |
    server {
      listen 80;
      location / { root /html; }
    }
```

### Da file esistenti (imperativo)

```bash
# Da un singolo file (nome chiave = nome file)
kubectl create configmap my-config --from-file=app.properties

# Da file con nome chiave personalizzato
kubectl create configmap my-config --from-file=application.conf=./local-app.conf

# Da una directory (ogni file → una chiave)
kubectl create configmap my-config --from-file=./config-dir/

# Da coppie key=value inline
kubectl create configmap my-config \
  --from-literal=DB_HOST=localhost \
  --from-literal=DB_PORT=5432

# Combinazioni
kubectl create configmap my-config \
  --from-literal=ENV=production \
  --from-file=app.properties \
  --from-file=nginx.conf=./custom-nginx.conf
```

### Struttura interna

```
ConfigMap
├── metadata.name       → nome della risorsa
├── metadata.namespace  → namespace (default se omesso)
├── immutable           → true/false (default: false)
└── data                → mappa chiave/valore (stringhe)
    ├── KEY_SIMPLE: "valore"
    └── file.conf: |
            contenuto
            multi-riga
```

> Il campo `binaryData` accetta valori in base64 per dati non UTF-8 (raro).

---

## 4. Modalità di consumo

Un ConfigMap può essere consumato in tre modi principali:

```
ConfigMap
    │
    ├─── 1. env singola ──► valueFrom.configMapKeyRef  → var d'ambiente specifica
    │
    ├─── 2. envFrom ──────► envFrom.configMapRef       → tutte le chiavi come env vars
    │
    └─── 3. volume ───────► spec.volumes.configMap     → chiavi come file su disco
```

---

## 5. Variabili d'ambiente singole (valueFrom)

Espone **chiavi specifiche** come variabili d'ambiente, con possibilità di rinominarle.

```yaml
spec:
  containers:
    - name: app
      image: myapp:latest
      env:
        # Nome variabile = DB_HOST, chiave ConfigMap = DB_HOST
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: my-config       # nome del ConfigMap
              key: DATABASE_HOST    # chiave da leggere

        # Rinomina: variabile SERVER_PORT ← chiave DATABASE_PORT
        - name: SERVER_PORT
          valueFrom:
            configMapKeyRef:
              name: my-config
              key: DATABASE_PORT

        # Chiave opzionale: il pod parte anche se la chiave non esiste
        - name: FEATURE_FLAG
          valueFrom:
            configMapKeyRef:
              name: my-config
              key: OPTIONAL_FLAG
              optional: true        # ← non fallisce se manca
```

### Vantaggi e limiti

| Pro                                          | Contro                                        |
|----------------------------------------------|-----------------------------------------------|
| Controllo granulare su quali chiavi esporre  | Verboso con molte chiavi                      |
| Rinomina della variabile                     | Lista hardcoded nel manifest del Deployment   |
| `optional: true` per chiavi facoltative      | Le env vars non si aggiornano a runtime       |

> **Importante**: le variabili d'ambiente vengono iniettate **alla creazione del container**. Se il ConfigMap cambia, il pod deve essere riavviato per vedere i nuovi valori.

---

## 6. Import massivo (envFrom)

Importa **tutte le chiavi** del ConfigMap come variabili d'ambiente in un colpo solo.

```yaml
spec:
  containers:
    - name: app
      image: myapp:latest
      envFrom:
        # Importa tutte le chiavi senza prefisso
        - configMapRef:
            name: app-config

        # Importa di nuovo con prefisso (evita conflitti di naming)
        - configMapRef:
            name: app-config
            prefix: "APP_"         # → APP_DB_HOST, APP_LOG_LEVEL, ...

        # Puoi combinare più ConfigMap
        - configMapRef:
            name: database-config
        - configMapRef:
            name: feature-flags-config
            optional: true         # il pod parte anche se il CM non esiste
```

### Regole di naming

Kubernetes richiede che le chiavi del ConfigMap usato con `envFrom` siano **nomi di variabili d'ambiente validi** (lettere, cifre, underscore; non iniziano con cifra). Chiavi con caratteri non validi (es. `my-key` con trattino) vengono **silenziosamente ignorate**.

```bash
# Verifica chiavi problematiche
kubectl get configmap my-config -o jsonpath='{range .data}{@}{"\n"}{end}'
```

---

## 7. Volume mount: file di configurazione

Monta il ConfigMap come una **directory**: ogni chiave diventa un file, il valore è il contenuto del file.

```yaml
spec:
  containers:
    - name: app
      image: myapp:latest
      volumeMounts:
        - name: config-vol
          mountPath: /etc/config    # directory creata nel container
          readOnly: true            # consigliato

  volumes:
    - name: config-vol
      configMap:
        name: my-config
        # Opzionale: seleziona solo alcune chiavi e/o rinominale
        # items:
        #   - key: app.properties
        #     path: application.properties    # nome file nel container
        #   - key: logging.yaml
        #     path: logging/config.yaml       # con sotto-directory
        # defaultMode: 0644                  # permessi (default: 0644)
```

### Risultato nel container

```
/etc/config/
├── app.properties       ← chiave "app.properties"
├── database.properties  ← chiave "database.properties"
└── logging.yaml         ← chiave "logging.yaml"
```

### Meccanismo di aggiornamento

Kubernetes usa **symlink atomici** per aggiornare i file montati:

```
/etc/config/
├── ..data -> ..2026_05_21_12_00_00.1234567  # symlink alla versione corrente
├── app.properties -> ..data/app.properties  # symlink
├── database.properties -> ..data/database.properties
└── ..2026_05_21_12_00_00.1234567/           # directory con i file reali
    ├── app.properties
    └── database.properties
```

Quando il ConfigMap viene aggiornato, kubelet crea una nuova directory con timestamp e redirige il symlink `..data` atomicamente.

---

## 8. subPath: mount di un singolo file

Permette di sovrascrivere un **singolo file** in una directory esistente nel container, senza rimpiazzare l'intera directory.

```yaml
volumeMounts:
  # Sovrascrive solo /etc/nginx/conf.d/default.conf
  # Il resto di /etc/nginx/ rimane intatto
  - name: nginx-conf
    mountPath: /etc/nginx/conf.d/default.conf
    subPath: default.conf          # nome della chiave nel ConfigMap
```

### Confronto: con e senza subPath

```
Senza subPath (mount directory):
  mountPath: /etc/app/
  → /etc/app/ viene sostituita completamente con i file del ConfigMap
  → File aggiornati automaticamente quando il ConfigMap cambia ✓

Con subPath (mount file singolo):
  mountPath: /etc/nginx/conf.d/default.conf
  subPath: default.conf
  → Solo quel file viene sostituito, il resto della dir è intatto ✓
  → Il file NON viene aggiornato automaticamente ✗ (richiede riavvio pod)
```

### Quando usare subPath

- Config che sovrascrive un file in una directory gestita dall'immagine (nginx.conf, my.cnf, etc.)
- Quando vuoi preservare altri file nella stessa directory

---

## 9. ConfigMap immutabili

Impostando `immutable: true`, il ConfigMap non può più essere modificato dopo la creazione.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: release-config-v2
immutable: true        # ← non modificabile dopo la creazione
data:
  API_VERSION: "v2"
  BUILD: "2026-05-21"
```

### Effetti

- Qualsiasi `kubectl apply`, `kubectl patch`, `kubectl edit` che tenta di modificare `data` viene **rifiutato** con errore.
- Il kubelet **non fa watch** delle variazioni → meno carico sull'API server in cluster grandi.
- Le **annotazioni** in `metadata` possono ancora essere modificate (non fanno parte di `data`).
- Per "aggiornare" un ConfigMap immutabile: **crea un nuovo** CM con un nuovo nome, aggiorna i Deployment, elimina il vecchio.

### Pattern di versioning consigliato

```
release-config-v1  →  release-config-v2  →  release-config-v3
                                ↑
                    Aggiorna envFrom.configMapRef.name
                    nei Deployment e roll out
```

```bash
# Crea nuova versione
kubectl create configmap release-config-v2 \
  --from-literal=API_VERSION=v2 \
  --from-literal=BUILD=2026-05-21 \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl patch configmap release-config-v2 --type=merge -p '{"immutable":true}'

# Aggiorna Deployment
kubectl set env deployment/my-app --from=configmap/release-config-v2

# Elimina vecchia versione (solo se non referenziata)
kubectl delete configmap release-config-v1
```

---

## 10. Dynamic reload

I file montati tramite **Volume** (senza `subPath`) vengono aggiornati automaticamente dal kubelet quando il ConfigMap cambia.

### Tempo di propagazione

| Ambiente         | Tempo tipico  | Parametro                                 |
|------------------|---------------|-------------------------------------------|
| Kind (Docker)    | 30–90 s       | `kubeletConfigFile.configMapAndSecretChangeDetectionStrategy` |
| Cluster prod     | ~1 min        | `--sync-period` del kubelet               |
| Con `cache: TTL` | Configurabile | `kube-apiserver --watch-cache`            |

### Cosa si aggiorna automaticamente

```
✓ Volume mount SENZA subPath   → file aggiornati da kubelet
✗ Volume mount CON subPath     → NON aggiornato (serve riavvio pod)
✗ Variabili d'ambiente (env / envFrom) → NON aggiornate (serve riavvio pod)
```

### Applicazione che supporta il reload

Le applicazioni devono essere scritte per **rilevare i cambiamenti del file** e ricaricare la configurazione senza riavviarsi:

```go
// Go: usa fsnotify per watch del file
watcher, _ := fsnotify.NewWatcher()
watcher.Add("/etc/config/app.properties")
for event := range watcher.Events {
    if event.Has(fsnotify.Create) { // kubelet usa CREATE per il flip del symlink
        reloadConfig()
    }
}
```

```python
# Python: rileggi il file a ogni richiesta (semplice ma non efficiente)
def get_feature_flag(name):
    with open("/etc/config/flags.json") as f:
        flags = json.load(f)
    return flags.get(name, False)
```

### Triggering manuale

Per applicazioni che non supportano il hot-reload (come nginx):

```bash
# Invia SIGHUP a nginx per ricaricare la config
kubectl exec <pod> -- nginx -s reload

# Con un loop in un sidecar container (pattern production)
# inotifywait -e create /etc/config && nginx -s reload
```

---

## 11. Limiti e best practice

### Limiti tecnici

| Limite              | Valore   | Note                                          |
|---------------------|----------|-----------------------------------------------|
| Dimensione massima  | 1 MiB    | Somma di tutti i valori in `data`             |
| Namespace           | Locale   | Un CM può essere usato solo nel suo namespace |
| Aggiornamento env   | No       | Env vars fissate alla creazione del container |
| Chiavi valide       | `[A-Za-z0-9._-]` | Per `envFrom` solo `[A-Za-z0-9_]`  |

### Best practice

```yaml
# 1. Usa label per organizzare e filtrare
metadata:
  labels:
    app: my-app
    component: config
    environment: production

# 2. Separa ConfigMap per ambiente (non usare namespace "default" in produzione)
#    dev-config, staging-config, prod-config

# 3. Versionamento: includi versione nel nome per ConfigMap immutabili
#    my-app-config-v3, my-app-config-2026-05-21

# 4. Non mettere dati sensibili: usa Secret
#    ConfigMap → DB_HOST, DB_PORT, LOG_LEVEL
#    Secret    → DB_PASSWORD, API_KEY, TLS_CERT

# 5. Usa readOnly: true per i volume mount
volumeMounts:
  - mountPath: /etc/config
    readOnly: true
```

### Anti-pattern comuni

```yaml
# ✗ MALE: dati sensibili in ConfigMap
data:
  DATABASE_PASSWORD: "superSecretPass123"  # usa un Secret!

# ✗ MALE: ConfigMap enorme con tutta la config
# Suddividi per componente: db-config, cache-config, app-config

# ✗ MALE: nomi non descrittivi
# my-config, config1, test-config → usa nomi come "api-server-config"

# ✗ MALE: aspettarsi env vars aggiornate senza riavvio
# Le variabili d'ambiente NON cambiano a runtime.
```

---

## 12. Comandi utili

### CRUD

```bash
# Crea da YAML
kubectl apply -f configmap.yaml

# Crea imperativo
kubectl create configmap my-config \
  --from-literal=KEY=value \
  --from-file=app.conf

# Elenca
kubectl get configmap
kubectl get cm                     # abbreviazione
kubectl get cm -A                  # tutti i namespace

# Dettagli
kubectl describe cm my-config
kubectl get cm my-config -o yaml

# Modifica interattiva
kubectl edit cm my-config

# Aggiornamento parziale
kubectl patch cm my-config --type=merge -p '{"data":{"KEY":"new-value"}}'

# Aggiunta/rimozione chiave
kubectl create cm my-config --from-literal=NEW_KEY=value \
  --dry-run=client -o yaml | kubectl apply -f -

# Elimina
kubectl delete cm my-config
```

### Debug e ispezione

```bash
# Mostra solo le chiavi (senza valori)
kubectl get cm my-config -o jsonpath='{range .data}{@}{"\n"}{end}'

# Estrai valore specifico
kubectl get cm my-config -o jsonpath='{.data.LOG_LEVEL}'

# Confronta ConfigMap tra namespace
kubectl get cm my-config -n dev -o yaml > dev.yaml
kubectl get cm my-config -n prod -o yaml > prod.yaml
diff dev.yaml prod.yaml

# Verifica file montato nel pod
kubectl exec <pod> -- cat /etc/config/app.properties

# Verifica variabile d'ambiente nel pod
kubectl exec <pod> -- env | grep DB_HOST

# Verifica se il CM è immutabile
kubectl get cm my-config -o jsonpath='{.immutable}'
```

### Reload

```bash
# Forza riavvio deployment (per aggiornare env vars)
kubectl rollout restart deployment/my-app

# Verifica aggiornamento file nel pod (senza riavvio)
kubectl exec <pod> -- cat /etc/config/app.properties

# Reload nginx (senza riavvio pod)
kubectl exec <pod> -- nginx -s reload
```

---

## 13. Scenari di questo lab

| Cartella          | Scenario                         | Concetti dimostrati                                     |
|-------------------|----------------------------------|---------------------------------------------------------|
| `01-env-vars/`    | Env var singole (valueFrom)      | `configMapKeyRef`, rinomina, `optional: true`           |
| `02-env-from/`    | Import massivo (envFrom)         | `envFrom`, `prefix`, import da più ConfigMap            |
| `03-volume-files/`| Volume mount multi-file          | chiavi come file, `readOnly`, symlink kubelet           |
| `04-nginx-config/`| nginx config da ConfigMap        | `subPath`, security headers, endpoint `/health`         |
| `05-immutable/`   | ConfigMap immutabile             | `immutable: true`, versioning, errore di modifica       |
| `06-dynamic-reload/`| Aggiornamento a runtime        | volume senza subPath, propagazione kubelet, hot reload  |

### Come usare i lab

```powershell
# Entra nella cartella
cd k8s-configmap-examples

# Esegui tutti gli scenari
.\00-deploy-all.ps1

# Oppure esegui un singolo scenario
.\00-deploy-all.ps1 -Scenario 4

# Oppure entra nella cartella e lancia direttamente
cd 01-env-vars
.\test.ps1

# Pulisci tutto
cd ..
.\99-cleanup-all.ps1
```

---

## Riferimenti

- [Documentazione ufficiale ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Configure a Pod to Use a ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- [ConfigMap immutabili](https://kubernetes.io/docs/concepts/configuration/configmap/#configmap-immutable)
- [ConfigMap e aggiornamento automatico](https://kubernetes.io/docs/concepts/configuration/configmap/#mounted-configmaps-are-updated-automatically)
- [API reference ConfigMap](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/config-map-v1/)
