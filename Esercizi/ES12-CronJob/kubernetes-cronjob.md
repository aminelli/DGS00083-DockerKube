# Kubernetes: CronJob

## Indice
1. [Cos'è un CronJob](#1-cosè-un-cronjob)
2. [CronJob vs Job](#2-cronjob-vs-job)
3. [Struttura del manifest](#3-struttura-del-manifest)
4. [Sintassi cron](#4-sintassi-cron)
5. [concurrencyPolicy](#5-concurrencypolicy)
6. [History limits](#6-history-limits)
7. [Suspend](#7-suspend)
8. [timeZone](#8-timezone)
9. [startingDeadlineSeconds](#9-startingdeadlineseconds)
10. [activeDeadlineSeconds](#10-activedeadlineseconds)
11. [Trigger manuale](#11-trigger-manuale)
12. [Comandi utili](#12-comandi-utili)
13. [Scenari del lab](#13-scenari-del-lab)

---

## 1. Cos'è un CronJob

Un **CronJob** è un controller Kubernetes che crea **Job** automaticamente secondo uno **schedule cron**. Ogni volta che lo schedule si attiva, il CronJob genera un Job figlio che a sua volta crea uno o più Pod.

```
CronJob ─── (schedule trigger) ──► Job ──► Pod(s)
              "* * * * *"            └──► Pod(s)
```

**Casi d'uso tipici**:
- Backup database periodici
- Report e aggregazioni notturne
- Pulizia / rotazione log
- Invio email / notifiche pianificate
- Sincronizzazione dati tra sistemi
- Cache warming

---

## 2. CronJob vs Job

| Caratteristica | Job | CronJob |
|---------------|-----|---------|
| Creazione | Manuale | Automatica (schedule) |
| Esecuzioni | Una sola volta | Ripetuta periodicamente |
| Controllo schedule | Nessuno | Espressione cron |
| Oggetto generato | Pod(s) | Job → Pod(s) |
| Cronologia | N/A | `successfulJobsHistoryLimit` |
| Parallelismo | `parallelism` | Per Job figlio |
| Concorrenza | N/A | `concurrencyPolicy` |
| Pausa | N/A | `suspend: true` |

---

## 3. Struttura del manifest

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: my-cronjob
  namespace: default
spec:
  # ─── Schedule ───────────────────────────────────────
  schedule: "0 2 * * *"           # ogni giorno alle 02:00 UTC
  timeZone: "Europe/Rome"         # (k8s >= 1.27) interpreta schedule in questo TZ

  # ─── Concorrenza ────────────────────────────────────
  concurrencyPolicy: Forbid       # Allow | Forbid | Replace

  # ─── Affidabilità ───────────────────────────────────
  startingDeadlineSeconds: 120    # tollera max 2 min di ritardo
  suspend: false                  # true = sospende le esecuzioni future

  # ─── Cronologia ─────────────────────────────────────
  successfulJobsHistoryLimit: 3   # quanti Job completati mantenere
  failedJobsHistoryLimit: 1       # quanti Job falliti mantenere

  # ─── Template del Job generato ──────────────────────
  jobTemplate:
    metadata:
      labels:
        app: my-cronjob
    spec:
      backoffLimit: 2             # tentativi prima di dichiarare il Job fallito
      activeDeadlineSeconds: 300  # il Job viene killato dopo 5 minuti
      ttlSecondsAfterFinished: 600  # auto-cleanup dopo 10 minuti

      template:
        spec:
          restartPolicy: OnFailure    # Never | OnFailure (Job: mai Always)
          containers:
            - name: worker
              image: busybox:1.36
              command: ["/bin/sh", "-c", "echo 'Eseguito il:' && date"]
              resources:
                requests: { cpu: 50m, memory: 32Mi }
                limits:   { cpu: 200m, memory: 64Mi }
```

---

## 4. Sintassi cron

```
┌─────────────── minuto      (0-59)
│  ┌──────────── ora         (0-23)
│  │  ┌───────── giorno/mese (1-31)
│  │  │  ┌────── mese        (1-12 o jan-dec)
│  │  │  │  ┌─── giorno/sett (0-7: 0=Sun, 7=Sun, 1=Mon...)
│  │  │  │  │
*  *  *  *  *
```

| Espressione | Significato |
|-------------|-------------|
| `* * * * *` | Ogni minuto |
| `0 * * * *` | Ogni ora (al minuto 0) |
| `0 8 * * *` | Ogni giorno alle 08:00 |
| `0 8 * * 1` | Ogni lunedì alle 08:00 |
| `0 2 * * 0` | Ogni domenica alle 02:00 |
| `0 0 1 * *` | Primo del mese a mezzanotte |
| `*/5 * * * *` | Ogni 5 minuti |
| `0 9-17 * * 1-5` | Ogni ora dalle 9 alle 17, lun-ven |
| `0 0 * * 1,3,5` | Lun/Mer/Ven a mezzanotte |
| `@hourly` | Alias per `0 * * * *` |
| `@daily` | Alias per `0 0 * * *` |
| `@weekly` | Alias per `0 0 * * 0` |
| `@monthly` | Alias per `0 0 1 * *` |

**Caratteri speciali**:

| Simbolo | Significato | Esempio |
|---------|-------------|---------|
| `*` | qualsiasi valore | `* * * * *` = ogni minuto |
| `,` | lista di valori | `1,15 * * * *` = al min 1 e 15 |
| `-` | intervallo | `0 9-17 * * *` = dalle 9 alle 17 |
| `/` | incremento | `*/10 * * * *` = ogni 10 min |

---

## 5. concurrencyPolicy

Definisce il comportamento quando un Job è ancora in esecuzione al momento del prossimo trigger:

```
Schedule: ogni minuto
Job duration: ~70 secondi

Allow (default):
  T+0:  Job-1 avviato  [running]
  T+60: Job-2 avviato  [running]  ← Job-1 ancora attivo
  T+70: Job-1 completa
  T+120: Job-3 avviato            ← Job-2 ancora attivo
  Rischio: accumulo di job se l'esecuzione è lenta

Forbid:
  T+0:  Job-1 avviato  [running]
  T+60: trigger        → SALTATO (Job-1 ancora attivo)
  T+70: Job-1 completa
  T+120: Job-3 avviato ✓
  Garanzia: massimo 1 job attivo

Replace:
  T+0:  Job-1 avviato  [running]
  T+60: Job-1 CANCELLATO → Job-2 avviato ✓
  T+120: Job-2 CANCELLATO → Job-3 avviato ✓
  Garanzia: sempre il job più recente, nessun accumulo
```

| Policy | Parallele | Salta | Cancella precedente |
|--------|-----------|-------|---------------------|
| `Allow` | Sì | No | No |
| `Forbid` | No | Sì | No |
| `Replace` | No | No | Sì |

---

## 6. History limits

```yaml
successfulJobsHistoryLimit: 3   # default: 3
failedJobsHistoryLimit:     1   # default: 1
```

I Job **completati** e **falliti** rimangono nel cluster come record storico, con i loro Pod. Questi limiti evitano l'accumulo di oggetti:

```
successfulJobsHistoryLimit: 3
  → mantiene gli ultimi 3 Job completati con successo
  → quando arriva il 4°, il più vecchio viene eliminato

successfulJobsHistoryLimit: 0
  → i Job vengono eliminati immediatamente dopo il completamento
  → nessuna cronologia, minimo utilizzo di risorse
```

**In alternativa**: `ttlSecondsAfterFinished` nel `jobTemplate.spec` elimina il Job N secondi dopo il completamento, indipendentemente dai limiti sopra:

```yaml
jobTemplate:
  spec:
    ttlSecondsAfterFinished: 300   # auto-delete dopo 5 minuti
```

---

## 7. Suspend

Permette di **mettere in pausa** un CronJob senza eliminarlo:

```yaml
spec:
  suspend: false   # default: il CronJob è attivo
```

```bash
# Sospendi: i prossimi trigger vengono ignorati
kubectl patch cronjob my-cronjob -p '{"spec":{"suspend":true}}'

# Riprendi: le esecuzioni riprendono al prossimo trigger
kubectl patch cronjob my-cronjob -p '{"spec":{"suspend":false}}'
```

**Nota**: mettere `suspend: true` **non** cancella i Job già in esecuzione. Blocca solo i trigger futuri.

---

## 8. timeZone

A partire da **Kubernetes 1.27** (stable), il campo `timeZone` permette di specificare il fuso orario per l'espressione cron:

```yaml
spec:
  schedule: "0 8 * * *"
  timeZone: "Europe/Rome"    # esegue alle 08:00 ora italiana (CET/CEST)
```

Senza `timeZone`, lo schedule viene interpretato in **UTC**.

**Esempi di timezone**:

| timeZone | Fuso |
|----------|------|
| `UTC` | Coordinated Universal Time |
| `Europe/Rome` | CET (UTC+1) / CEST (UTC+2) |
| `America/New_York` | EST (UTC-5) / EDT (UTC-4) |
| `Asia/Tokyo` | JST (UTC+9) |
| `America/Los_Angeles` | PST (UTC-8) / PDT (UTC-7) |

Il nome del timezone deve seguire il formato del **tz database** (IANA Time Zone Database).

```bash
# Verifica la timezone supportata dal cluster
kubectl get cronjob my-cronjob -o jsonpath='{.spec.timeZone}'
```

**Requisiti**: Kubernetes >= 1.27, cluster compilato con `tzdata`.

---

## 9. startingDeadlineSeconds

Tolleranza per il ritardo di avvio quando il controller era **offline o sovraccarico**:

```yaml
spec:
  startingDeadlineSeconds: 120   # tollera fino a 2 minuti di ritardo
```

```
Scenario: controller offline per 10 minuti
Schedule: ogni minuto
startingDeadlineSeconds: 120 (2 minuti)

  → Mancati trigger durante l'offline: 10
  → Finestra di recupero: 2 minuti = 2 trigger
  → Recuperati: 2 (i più recenti)
  → Saltati: 8
```

**Comportamento**:
- Se il ritardo supera `startingDeadlineSeconds`: il trigger viene saltato
- Se `startingDeadlineSeconds` non è impostato: il controller cerca di recuperare **tutti** i trigger mancati (può essere costoso)
- Se vengono saltati più di **100 trigger** consecutivi: il CronJob viene disabilitato con errore

---

## 10. activeDeadlineSeconds

Definito nel `jobTemplate.spec`, limita la durata **del singolo Job**:

```yaml
jobTemplate:
  spec:
    activeDeadlineSeconds: 300   # il Job viene killato dopo 5 minuti
    backoffLimit: 2              # max 2 retry per Pod fallito
```

```
Job avviato alle 10:00:00
  10:00:00 → Pod-1 avviato
  10:02:00 → Pod-1 fallisce (exit 1) → retry
  10:04:00 → Pod-2 avviato
  10:05:00 → activeDeadlineSeconds raggiunto → Job KILLED
             (anche se il Pod stava ancora girando)
```

**Differenza con `backoffLimit`**:
- `backoffLimit`: limita i **retry** (tentativi per Pod)
- `activeDeadlineSeconds`: limita il **tempo totale** del Job

---

## 11. Trigger manuale

Crea un Job **on-demand** da un CronJob esistente, senza aspettare lo schedule:

```bash
# Sintassi
kubectl create job <nome-job> --from=cronjob/<nome-cronjob>

# Esempio
kubectl create job manual-run-1 --from=cronjob/my-cronjob

# Esecuzione con namespace
kubectl create job backup-now --from=cronjob/db-backup -n production
```

Il Job creato manualmente:
- Eredita il `jobTemplate` del CronJob (stesso container, stesse env var, stesse risorse)
- **Non** viene conteggiato nel `successfulJobsHistoryLimit`
- È indipendente dallo schedule: non interferisce con le esecuzioni pianificate
- Ha come label `batch.kubernetes.io/cronjob-uid` che lo collega al CronJob

```bash
# Verifica il Job creato manualmente
kubectl get jobs
kubectl describe job manual-run-1
```

---

## 12. Comandi utili

```bash
# Lista CronJob
kubectl get cronjobs
kubectl get cj            # abbreviazione

# Stato (include LAST SCHEDULE e ACTIVE)
kubectl get cj my-cronjob

# Dettaglio completo
kubectl describe cj my-cronjob

# Sospendi / riprendi
kubectl patch cj my-cronjob -p '{"spec":{"suspend":true}}'
kubectl patch cj my-cronjob -p '{"spec":{"suspend":false}}'

# Modifica lo schedule
kubectl patch cj my-cronjob -p '{"spec":{"schedule":"0 3 * * *"}}'

# Trigger manuale
kubectl create job run-now --from=cronjob/my-cronjob

# Mostra i Job creati da un CronJob
kubectl get jobs --selector=batch.kubernetes.io/controller-uid=$(kubectl get cj my-cronjob -o jsonpath='{.metadata.uid}')

# Log dell'ultimo Job
LATEST_JOB=$(kubectl get jobs --selector=batch.kubernetes.io/job-name -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
kubectl logs -l job-name=$LATEST_JOB

# Elimina un CronJob (e i suoi Job/Pod)
kubectl delete cronjob my-cronjob

# Watch in tempo reale
kubectl get jobs -w
kubectl get pods -w

# PowerShell: stato di tutti i CronJob
kubectl get cronjobs -o jsonpath='{range .items[*]}{.metadata.name}{"  schedule="}{.spec.schedule}{"  suspend="}{.spec.suspend}{"  lastSchedule="}{.status.lastScheduleTime}{"\n"}{end}'
```

---

## 13. Scenari del lab

| # | Cartella | Scenario | Concetti chiave |
|---|----------|----------|-----------------|
| 01 | `01-basic/` | CronJob ogni minuto | Struttura base, schedule, backoffLimit, ttl |
| 02 | `02-concurrency/` | Allow / Forbid / Replace | Job sovrapposti, accumulazione, soppressione |
| 03 | `03-history/` | History limits | successfulJobsHistoryLimit, failedJobsHistoryLimit |
| 04 | `04-suspend/` | Suspend e ripresa | Pausa pianificazione, patch suspend |
| 05 | `05-timezone/` | timeZone | UTC vs Europe/Rome vs America/New_York |
| 06 | `06-manual-trigger/` | Trigger manuale | kubectl create job --from=cronjob |

### Esecuzione rapida

```powershell
# Tutti gli scenari
.\00-deploy-all.ps1

# Solo uno scenario
.\00-deploy-all.ps1 -Scenario 2

# Cleanup completo
.\99-cleanup-all.ps1
```

### Prerequisiti

- Kind cluster attivo: `kubectl cluster-info`
- Immagine: `busybox:1.36`
- Scenario 05 (`timeZone`): Kubernetes >= 1.27

---

*Documentazione generata per il lab `k8s-cronjob-examples` — Kind + Docker Desktop.*
