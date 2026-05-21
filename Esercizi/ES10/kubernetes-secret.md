# Kubernetes Secret

## Indice
1. [Cos'è un Secret](#1-cosè-un-secret)
2. [Secret vs ConfigMap](#2-secret-vs-configmap)
3. [Tipi di Secret](#3-tipi-di-secret)
4. [Creare un Secret](#4-creare-un-secret)
5. [Iniezione come variabili d'ambiente (valueFrom)](#5-iniezione-come-variabili-dambiente-valuefrom)
6. [Import massivo con envFrom](#6-import-massivo-con-envfrom)
7. [Mount come volume (file)](#7-mount-come-volume-file)
8. [TLS Secret](#8-tls-secret)
9. [Docker Registry pull Secret](#9-docker-registry-pull-secret)
10. [ServiceAccount e Token Secret](#10-serviceaccount-e-token-secret)
11. [Sicurezza: best practice](#11-sicurezza-best-practice)
12. [Comandi utili](#12-comandi-utili)
13. [Scenari del lab](#13-scenari-del-lab)

---

## 1. Cos'è un Secret

Un **Secret** è un oggetto Kubernetes progettato per contenere dati sensibili: password, token, chiavi TLS, credenziali di registry, ecc. A differenza di stringhe hardcoded nei manifesti o nei ConfigMap, i Secret permettono di:

- Separare i segreti dal codice e dagli artefatti di build
- Applicare policy RBAC per limitare chi può leggere i valori
- Abilitare la cifratura at-rest nell'API Server
- Integrarsi con sistemi di secrets management esterni (Vault, ESO, SOPS)

> ⚠ **Nota critica**: di default i Secret sono archiviati in etcd **non cifrati** (solo base64). La sicurezza reale richiede [Encryption at Rest](#111-encryption-at-rest) e RBAC restrittivo.

---

## 2. Secret vs ConfigMap

| Caratteristica          | ConfigMap                     | Secret                            |
|-------------------------|-------------------------------|-----------------------------------|
| Scopo                   | Configurazione non sensibile  | Dati sensibili                    |
| Encoding storage        | Testo chiaro                  | Base64 (decodificato in-memory)   |
| Cifratura at-rest       | No (default)                  | Supportata (richiede config)      |
| RBAC                    | Sì                            | Sì (consigliato: più restrittivo) |
| `immutable`             | Sì (k8s ≥ 1.21)               | Sì (k8s ≥ 1.21)                   |
| Dimensione max          | 1 MiB                         | 1 MiB                             |

**Regola pratica**: se il valore comparisse in chiaro in un log di CI, è un Secret.

---

## 3. Tipi di Secret

| Tipo                                  | Uso                                                     |
|---------------------------------------|---------------------------------------------------------|
| `Opaque`                              | Generico (default), qualsiasi coppia chiave-valore       |
| `kubernetes.io/tls`                   | Certificato TLS (`tls.crt` + `tls.key`)                 |
| `kubernetes.io/dockerconfigjson`      | Credenziali pull registry (`~/.docker/config.json`)     |
| `kubernetes.io/dockercfg`             | Formato legacy Docker (`~/.dockercfg`)                  |
| `kubernetes.io/service-account-token` | Token associato a un ServiceAccount (k8s < 1.24 auto)  |
| `kubernetes.io/basic-auth`            | Username + password per autenticazione basic            |
| `kubernetes.io/ssh-auth`              | Chiave privata SSH                                      |
| `bootstrap.kubernetes.io/token`       | Token di bootstrap (per aggiungere nodi)                |

---

## 4. Creare un Secret

### 4.1 Modo imperativo

```bash
# Generico (Opaque)
kubectl create secret generic db-credentials \
  --from-literal=username=myuser \
  --from-literal=password=s3cr3t

# Da file
kubectl create secret generic app-certs \
  --from-file=ca.crt=./ca.crt \
  --from-file=client.crt=./client.crt

# TLS
kubectl create secret tls my-tls \
  --cert=tls.crt \
  --key=tls.key

# Docker registry
kubectl create secret docker-registry registry-creds \
  --docker-server=registry.example.com \
  --docker-username=ci-user \
  --docker-password=MyP@ss
```

### 4.2 YAML con `stringData` (consigliato)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:           # valori in chiaro → Kubernetes converte in base64
  username: myuser
  password: s3cr3t
  connection-string: "postgres://myuser:s3cr3t@db:5432/mydb"
```

### 4.3 YAML con `data` (base64)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials-b64
type: Opaque
data:                 # valori già in base64
  username: bXl1c2Vy        # echo -n "myuser" | base64
  password: czNjcjN0        # echo -n "s3cr3t" | base64
```

> `stringData` e `data` producono lo stesso risultato. `stringData` è più leggibile ma **non deve essere commissionato in git** con valori reali — usa [SOPS](#112-sops--sealed-secrets) o variabili CI.

---

## 5. Iniezione come variabili d'ambiente (valueFrom)

```yaml
env:
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: db-credentials    # nome del Secret
        key: username           # chiave all'interno del Secret
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: password
  # Chiave opzionale: il pod NON fallisce se la chiave non esiste
  - name: DB_REPLICA
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: replica-host
        optional: true
```

> ⚠ Le env var **non si aggiornano** se il Secret cambia dopo il deploy. Occorre riavviare il pod.

---

## 6. Import massivo con envFrom

```yaml
envFrom:
  # Importa TUTTE le chiavi del Secret come env var
  - secretRef:
      name: app-secrets

  # Stesse chiavi con prefisso (evita collisioni)
  - secretRef:
      name: app-secrets
      prefix: "SEC_"
```

**Pro**: comodo per importare tanti segreti.  
**Contro**: tutte le chiavi diventano variabili, difficile controllare quali sono esposte. Preferire `valueFrom` quando possibile.

---

## 7. Mount come volume (file)

```yaml
volumes:
  - name: secret-vol
    secret:
      secretName: app-secret-files
      defaultMode: 0400     # rw solo per owner (root nel container)
      # items:              # opzionale: montare solo alcune chiavi
      #   - key: api-key.txt
      #     path: api-key.txt
      #     mode: 0400

containers:
  - volumeMounts:
      - name: secret-vol
        mountPath: /etc/secrets
        readOnly: true
```

### Comportamento importante

| Caratteristica           | Dettaglio                                                  |
|--------------------------|------------------------------------------------------------|
| Auto-update              | Sì (senza `subPath`) — kubelet sincronizza ogni ~60s       |
| `subPath`                | File **non** si aggiorna automaticamente                   |
| `defaultMode`            | Ottale (es. `0400` = rw owner only, `0640` = rw+r group)  |
| File nascosti (`.pgpass`)| Supportati come normali chiavi                             |

Ogni chiave del Secret diventa un file in `mountPath`. Il contenuto è già decodificato da base64 da Kubernetes.

---

## 8. TLS Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-tls-cert
type: kubernetes.io/tls
data:
  tls.crt: <base64 del certificato PEM>
  tls.key: <base64 della chiave privata PEM>
```

**Generazione con openssl**:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=myapp.local/O=MyOrg" \
  -addext "subjectAltName=DNS:myapp.local"

kubectl create secret tls my-tls-cert \
  --cert=tls.crt --key=tls.key
```

**Uso con Ingress**:
```yaml
spec:
  tls:
    - hosts:
        - myapp.local
      secretName: my-tls-cert
  rules:
    - host: myapp.local
      ...
```

**In produzione**: usa [cert-manager](https://cert-manager.io/) per il rinnovo automatico via Let's Encrypt o CA interne.

---

## 9. Docker Registry pull Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-creds
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "registry.example.com": {
          "username": "ci-user",
          "password": "MyToken",
          "auth": "<base64 di user:password>"
        }
      }
    }
```

**Uso in un Pod**:
```yaml
spec:
  imagePullSecrets:
    - name: registry-creds
  containers:
    - image: registry.example.com/myapp:1.0
```

**Associare a un ServiceAccount** (tutti i pod del SA ereditano il pull secret):
```bash
kubectl patch serviceaccount default \
  -p '{"imagePullSecrets": [{"name": "registry-creds"}]}'
```

---

## 10. ServiceAccount e Token Secret

### 10.1 ServiceAccount

Un **ServiceAccount** è un'identità per i processi nei pod. Ogni namespace ha un SA `default`. Il token SA è automaticamente montato in:
```
/var/run/secrets/kubernetes.io/serviceaccount/
  ├── token      ← JWT firmato dall'API Server
  ├── ca.crt     ← CA del cluster per verificare il server
  └── namespace  ← namespace del pod
```

### 10.2 Token persistente (k8s ≥ 1.24)

Dalla 1.24, Kubernetes non crea più un Secret di tipo `service-account-token` automaticamente. Per token persistenti (CI/CD, tool esterni):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-sa-token
  annotations:
    kubernetes.io/service-account.name: my-sa
type: kubernetes.io/service-account-token
```

Kubernetes popola automaticamente `data.token`, `data.ca.crt` e `data.namespace`.

### 10.3 RBAC minimo

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
subjects:
  - kind: ServiceAccount
    name: my-sa
    namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## 11. Sicurezza: best practice

### 11.1 Encryption at Rest

Di default etcd salva i Secret in chiaro (solo base64). Per cifrare:

```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <32-byte base64 key>
      - identity: {}
```

Poi avviare `kube-apiserver` con `--encryption-provider-config=...`.

### 11.2 SOPS / Sealed Secrets

Non commissionare mai Secret in chiaro su git. Opzioni:

| Tool | Approccio |
|------|-----------|
| **SOPS** | Cifra il file YAML con AWS KMS / GCP KMS / age |
| **Sealed Secrets** | Controller nel cluster, `SealedSecret` CRD (solo il cluster può decifrare) |
| **External Secrets Operator** | Sincronizza da Vault / AWS Secrets Manager / Azure Key Vault |
| **HashiCorp Vault** | Secrets engine completo, integrazione nativa con K8s |

### 11.3 RBAC per i Secret

```bash
# Impedire la lettura dei Secret al SA default:
kubectl create role secret-reader \
  --verb=get,list \
  --resource=secrets \
  --resource-name=my-specific-secret

# Verifica:
kubectl auth can-i get secrets --as=system:serviceaccount:default:default
```

Principio del **least privilege**: concedere solo `get` su Secret specifici, non `list` su tutti.

### 11.4 Regole generali

- Non stampare mai il **valore** di un Secret in log, stdout o descrizioni Kubernetes
- Usare `optional: true` in `secretKeyRef` solo se davvero opzionale
- Ruotare i Secret periodicamente; `immutable: true` obbliga la rotazione esplicita
- Usare `automountServiceAccountToken: false` sui pod che non chiamano l'API K8s
- Audit log: abilitare `audit-policy.yaml` per tracciare accessi ai Secret

---

## 12. Comandi utili

```bash
# Lista Secret nel namespace
kubectl get secret

# Dettagli (senza valori decodificati)
kubectl describe secret my-secret

# Struttura completa (base64)
kubectl get secret my-secret -o yaml

# Decodifica un singolo valore (PowerShell)
kubectl get secret my-secret -o jsonpath='{.data.username}' |
  % { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }

# Decodifica un singolo valore (bash)
kubectl get secret my-secret -o jsonpath='{.data.username}' | base64 -d

# Modifica un Secret
kubectl edit secret my-secret

# Patch con nuovo valore (stringData → Kubernetes converte)
kubectl patch secret my-secret --type=merge \
  -p '{"stringData":{"password":"newpassword"}}'

# Creare da env-file
kubectl create secret generic my-secret --from-env-file=.env

# Tipo del Secret
kubectl get secret my-secret -o jsonpath='{.type}'

# Chiavi presenti (solo nomi, non valori)
kubectl get secret my-secret -o jsonpath='{.data}' | \
  python3 -c "import sys,json; [print(k) for k in json.load(sys.stdin)]"

# Verifica RBAC per un SA
kubectl auth can-i list secrets --as=system:serviceaccount:default:my-sa

# Eliminare un Secret
kubectl delete secret my-secret
```

---

## 13. Scenari del lab

| # | Cartella | Scenario | Concetti chiave |
|---|----------|----------|-----------------|
| 01 | `01-opaque/` | Secret Opaque con `valueFrom` | `stringData`, `data`, base64, `secretKeyRef`, `optional` |
| 02 | `02-env-from/` | Import massivo con `envFrom` | `secretRef`, `prefix`, namespace pollution |
| 03 | `03-volume-files/` | Mount come file su volume | `defaultMode`, `readOnly`, auto-update, `.pgpass` |
| 04 | `04-tls/` | TLS Secret (certificato self-signed) | `kubernetes.io/tls`, openssl, cert-manager |
| 05 | `05-docker-registry/` | Pull Secret da registry privato | `dockerconfigjson`, `imagePullSecrets`, patch SA |
| 06 | `06-service-account/` | ServiceAccount + Token + RBAC | SA token, `service-account-token`, Role, RoleBinding |

### Esecuzione rapida

```powershell
# Tutti gli scenari
.\00-deploy-all.ps1

# Solo uno scenario
.\00-deploy-all.ps1 -Scenario 3

# Cleanup completo
.\99-cleanup-all.ps1
```

### Prerequisiti

- Kind cluster attivo (`kubectl cluster-info`)
- `openssl` nel PATH per lo scenario 04 (incluso in Git for Windows)
- `curlimages/curl:8.7.1` e `busybox:1.36` disponibili (pubblici su Docker Hub)

---

*Documentazione generata per il lab `k8s-secret-examples` — Kind + Docker Desktop.*
