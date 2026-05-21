# Kubernetes Job e CronJob — Guida Completa

## Indice

- [Kubernetes Job e CronJob — Guida Completa](#kubernetes-job-e-cronjob--guida-completa)
  - [Indice](#indice)
  - [Job vs CronJob — panoramica](#job-vs-cronjob--panoramica)
  - [Job](#job)
    - [Ciclo di vita](#ciclo-di-vita)
    - [Campi principali del Job](#campi-principali-del-job)
    - [Pattern 1: One-Shot](#pattern-1-one-shot)
    - [Pattern 2: Parallelo Indexed](#pattern-2-parallelo-indexed)
    - [Pattern 3: Completions Sequenziali](#pattern-3-completions-sequenziali)
    - [`restartPolicy`: Never vs OnFailure](#restartpolicy-never-vs-onfailure)
  - [CronJob](#cronjob)
    - [Sintassi schedule cron](#sintassi-schedule-cron)
    - [Campi principali del CronJob](#campi-principali-del-cronjob)
    - [`concurrencyPolicy`](#concurrencypolicy)
    - [History e cleanup](#history-e-cleanup)
  - [Confronto riepilogativo](#confronto-riepilogativo)
  - [Trigger manuale di un CronJob](#trigger-manuale-di-un-cronjob)
  - [Comandi utili](#comandi-utili)
  - [Struttura degli esempi in questa cartella](#struttura-degli-esempi-in-questa-cartella)

---

## Job vs CronJob — panoramica

| | **Job** | **CronJob** |
|---|---|---|
| **Scopo** | Esecuzione una-tantum di un task | Esecuzione pianificata periodica |
| **Trigger** | Manuale (`kubectl apply`) | Automatico (schedule cron) |
| **Durata** | Finita (termina con successo/fallimento) | Infinita (crea Job ad ogni tick) |
| **API** | `batch/v1 Job` | `batch/v1 CronJob` |exit
| **Analogia** | Script batch eseguito una volta | Cron daemon del sistema operativo |

**Un CronJob non è altro che un factory di Job**: ad ogni tick dello schedule, crea un nuovo oggetto `Job` nel cluster.

```
CronJob (schedule: "0 2 * * *")
     │
     ├── Job  [2026-05-21 02:00]  ← Completed
     ├── Job  [2026-05-22 02:00]  ← Completed
     └── Job  [2026-05-23 02:00]  ← Running
               │
               ├── Pod A
               └── Pod B
```

---

## Job

### Ciclo di vita

```
kubectl apply -f job.yaml
       │
       ▼
  Job creato  (status: Active)
       │
       ▼
  Pod creato (restartPolicy: Never → nuovo Pod per ogni retry)
       │
  ┌────┴─────────────────────────────┐
  │ Pod Running                      │
  │   exit 0 ──────────────────────► Pod Succeeded
  │   exit ≠ 0 ─► (retry ≤ backoffLimit) Pod Failed
  └──────────────────────────────────┘
       │
  tutte le completions raggiunte?
       │ Sì
       ▼
  Job Completed  →  (dopo ttlSecondsAfterFinished) → eliminato
```

### Campi principali del Job

```yaml
apiVersion: batch/v1
kind: Job
spec:
  # --- Completions e parallelismo ---
  completions: 1          # N di Pod che devono terminare con successo (default: 1)
  parallelism: 1          # N di Pod attivi contemporaneamente (default: 1)
  completionMode: NonIndexed  # NonIndexed (default) | Indexed

  # --- Gestione errori ---
  backoffLimit: 6         # max retry per fallimento (default: 6)
  activeDeadlineSeconds: 600  # timeout globale del Job in secondi

  # --- Cleanup ---
  ttlSecondsAfterFinished: 300  # secondi prima dell'auto-eliminazione post-completion

  template:
    spec:
      restartPolicy: Never   # Never | OnFailure  (Required: NON usare Always)
      containers:
        - name: worker
          image: busybox:1.36
```

### Pattern 1: One-Shot

Il caso più semplice: un Pod, un'esecuzione, un risultato.

```yaml
spec:
  completions: 1     # default
  parallelism: 1     # default
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sh", "-c", "echo 'Task completato'"]
```

**Casi d'uso**: invio email one-time, generazione report, script di migrazione.

### Pattern 2: Parallelo Indexed

Più worker attivi contemporaneamente. Con `completionMode: Indexed`, ogni Pod riceve
la variabile d'ambiente `JOB_COMPLETION_INDEX` (0-based) per sapere quale shard elaborare.

```yaml
spec:
  completions: 6          # 6 unità di lavoro totali
  parallelism: 3          # 3 Pod contemporanei
  completionMode: Indexed # ogni Pod conosce il proprio indice
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sh", "-c"]
          args:
            - |
              echo "Elaboro shard: $JOB_COMPLETION_INDEX"
              # logica per indice $JOB_COMPLETION_INDEX
```

**Esecuzione**: Kubernetes avvia i Pod 0, 1, 2 → appena uno finisce avvia il 3 → poi 4 → poi 5.

**Casi d'uso**: elaborazione parallela di dataset partizionati, rendering frame video,
transcodifica batch, indicizzazione search engine.

### Pattern 3: Completions Sequenziali

Più esecuzioni in sequenza (`parallelism: 1`). Ogni Pod elabora il "prossimo item"
da una coda esterna (Redis, SQS, DB).

```yaml
spec:
  completions: 4          # 4 run sequenziali
  parallelism: 1          # un Pod alla volta
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrator
          image: busybox:1.36
          command: ["sh", "-c"]
          args:
            - |
              # Prendi il prossimo item dalla coda
              ITEM=$(redis-cli LPOP work-queue)
              process "$ITEM"
```

**Casi d'uso**: migrazione step-by-step, operazioni che richiedono accesso esclusivo
al database, import CSV righe per riga.

### `restartPolicy`: Never vs OnFailure

| | `Never` | `OnFailure` |
|---|---|---|
| In caso di errore | Crea un **nuovo Pod** | **Riavvia** lo stesso Pod |
| Contatore retry | `backoffLimit` su nuovi Pod | `backoffLimit` su riavvii del Pod |
| Log storici | Visibili sui Pod vecchi | Sovrascrittura log ad ogni restart |
| Raccomandato per | Job che non devono perdere output/log | Job leggeri dove lo stato è esterno |

---

## CronJob

### Sintassi schedule cron

```
┌─────────── minuto      (0 - 59)
│ ┌───────── ora         (0 - 23)
│ │ ┌─────── giorno mese (1 - 31)
│ │ │ ┌───── mese        (1 - 12)
│ │ │ │ ┌─── giorno sett.(0 - 6, domenica = 0 o 7)
│ │ │ │ │
* * * * *
```

| Schedule | Significato |
|---|---|
| `"*/5 * * * *"` | Ogni 5 minuti |
| `"0 * * * *"` | Ogni ora (al minuto :00) |
| `"0 2 * * *"` | Ogni giorno alle 02:00 |
| `"0 9 * * 1-5"` | Giorni feriali alle 09:00 |
| `"0 2 * * 0"` | Ogni domenica alle 02:00 |
| `"0 9 1 * *"` | Il 1° di ogni mese alle 09:00 |
| `"0 0 1 1 *"` | Il 1° gennaio a mezzanotte |
| `"@hourly"` | Alias: `"0 * * * *"` |
| `"@daily"` | Alias: `"0 0 * * *"` |
| `"@weekly"` | Alias: `"0 0 * * 0"` |
| `"@monthly"` | Alias: `"0 0 1 * *"` |

> **Timezone**: dal Kubernetes 1.27 puoi specificare `timeZone: "Europe/Rome"`.
> Prima di 1.27 lo schedule è sempre in UTC.

### Campi principali del CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: my-cronjob
spec:
  schedule: "0 2 * * *"             # schedule cron (obbligatorio)
  timeZone: "Europe/Rome"           # timezone (>= 1.27, default UTC)

  # --- Concorrenza ---
  concurrencyPolicy: Forbid         # Allow | Forbid | Replace

  # --- Tolleranza ai miss ---
  startingDeadlineSeconds: 60       # max secondi di ritardo tollerato

  # --- History ---
  successfulJobsHistoryLimit: 3     # Job completati da conservare (default 3)
  failedJobsHistoryLimit: 1         # Job falliti da conservare (default 1)

  # --- Sospensione ---
  suspend: false                    # true = sospende nuove esecuzioni

  jobTemplate:                      # template del Job creato ad ogni tick
    spec:
      backoffLimit: 2
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: task
              image: busybox:1.36
              command: ["sh", "-c", "echo 'Eseguito alle' $(date)"]
```

### `concurrencyPolicy`

Definisce il comportamento quando un'esecuzione è ancora attiva al prossimo trigger.

```
Timeline:  |---Job A (90s)---|
           ↑                ↑
        T=0:00           T=1:00  ← prossimo trigger
                            │
                            ├── Allow   → avvia Job B (ora ci sono A e B attivi)
                            ├── Forbid  → SALTA Job B (A è ancora attivo)
                            └── Replace → TERMINA Job A, avvia Job B
```

| Valore | Comportamento | Quando usarlo |
|---|---|---|
| `Allow` | Esecuzioni multiple simultanee | Job idempotenti, statisticamente brevi |
| `Forbid` | Salta se il precedente è attivo | DB operations, invio email unico, lock-sensitive |
| `Replace` | Termina il vecchio, avvia il nuovo | Job "freschi" dove la run precedente è obsoleta |

### History e cleanup

Kubernetes mantiene gli oggetti `Job` (e i relativi `Pod`) nella history per permettere
il debug post-mortem.

```yaml
spec:
  successfulJobsHistoryLimit: 3   # mantieni 3 job "Completed"
  failedJobsHistoryLimit: 1       # mantieni 1 job "Failed"
```

| Limite | Comportamento |
|---|---|
| `0` | I Job vengono eliminati immediatamente (nessun log accessibile) |
| `1` | Mantieni solo l'ultimo Job |
| `N` | Mantieni gli ultimi N Job; il più vecchio viene eliminato quando se ne aggiunge uno nuovo |

**Raccomandazione produzione**: imposta `successfulJobsHistoryLimit: 3` e
`failedJobsHistoryLimit: 3` abbinando un sistema di log centralizzato (Loki, EFK)
per la storia completa.

---

## Confronto riepilogativo

| Scenario | `completions` | `parallelism` | `completionMode` | Pattern |
|---|---|---|---|---|
| One-shot | 1 | 1 | NonIndexed | Un task, un pod |
| Parallelo | N | M (M < N) | Indexed | N shard, M worker simultanei |
| Sequenziale | N | 1 | NonIndexed | N run in sequenza |
| Work queue | non impostato | M | NonIndexed | Pod prendono da coda esterna |

---

## Trigger manuale di un CronJob

Per eseguire subito un CronJob senza aspettare lo schedule:

```bash
kubectl create job --from=cronjob/<nome-cronjob> <nome-job-manuale>

# Esempio:
kubectl create job --from=cronjob/report-daily report-daily-manual-001
```

Utile per:
- Test e debug del CronJob
- Re-esecuzione di un job fallito
- Trigger in risposta a eventi (CI/CD pipeline)

---

## Comandi utili

```bash
# ── Job ──────────────────────────────────────────────────────

# Lista tutti i Job con stato
kubectl get jobs -o wide

# Dettaglio completo (inclusi Events)
kubectl describe job <nome>

# Log del Pod di un Job
kubectl logs job/<nome>

# Log di un Pod specifico (se ci sono più retry)
kubectl logs <nome-pod>

# Attendi completamento (bloccante, utile in script)
kubectl wait --for=condition=complete job/<nome> --timeout=120s

# Elimina un Job (e i suoi Pod)
kubectl delete job <nome>

# Elimina tutti i Job completati
kubectl delete jobs --field-selector status.successful=1


# ── CronJob ──────────────────────────────────────────────────

# Lista CronJob con ultimo schedule e stato
kubectl get cronjobs -o wide

# Dettaglio (mostra schedule, concurrencyPolicy, history)
kubectl describe cronjob <nome>

# Trigger manuale immediato
kubectl create job --from=cronjob/<nome> <nome-job>

# Sospendi un CronJob (non crea nuovi Job finché suspend=true)
kubectl patch cronjob <nome> -p '{"spec":{"suspend":true}}'

# Riprendi un CronJob sospeso
kubectl patch cronjob <nome> -p '{"spec":{"suspend":false}}'

# Modifica lo schedule
kubectl patch cronjob <nome> -p '{"spec":{"schedule":"0 3 * * *"}}'

# Elimina un CronJob (e la sua history di Job)
kubectl delete cronjob <nome>


# ── Debug ────────────────────────────────────────────────────

# Controlla perché un Pod è fallito
kubectl describe pod <nome-pod>

# Vedi tutti i Pod di un Job (inclusi quelli falliti)
kubectl get pods -l job-name=<nome-job> --show-all

# Esporta YAML del Job generato da un CronJob (per ispezione)
kubectl get job <nome-job> -o yaml
```

---

## Struttura degli esempi in questa cartella

```
k8s-jobs-examples/
├── 00-deploy-all.ps1              ← deploy tutti gli scenari
├── 99-cleanup-all.ps1             ← rimuove tutte le risorse
│
├── 01-job-simple/                 ← Job one-shot (1 pod, 1 run)
│   ├── job.yaml
│   └── test.ps1
│
├── 02-job-parallel/               ← Job parallelo Indexed (3 worker × 6 shard)
│   ├── job.yaml
│   └── test.ps1
│
├── 03-job-completions/            ← Job sequenziale (4 run, 1 alla volta)
│   ├── job.yaml
│   └── test.ps1
│
├── 04-cronjob-simple/             ← CronJob ogni 2 min + trigger manuale
│   ├── cronjob.yaml
│   └── test.ps1
│
├── 05-cronjob-concurrency/        ← CronJob con concurrencyPolicy: Forbid
│   ├── cronjob.yaml
│   └── test.ps1
│
└── 06-cronjob-history/            ← CronJob con history limits + fallimenti casuali
    ├── cronjob.yaml
    └── test.ps1
```
