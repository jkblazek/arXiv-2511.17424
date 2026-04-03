# arXiv-2511.17424
The Effects of Latency on a Progressive Second-Price Auction
------------------------------------------------------------

Got it — here’s a **clean GitHub-ready `README.md`** (Markdown, concise, no noise, copy-paste ready):

---

# PSP Seasons Simulation

Julia-based simulation pipeline with support for:

* Local execution
* Dockerized runs
* Distributed execution via Azure Batch

Designed for reproducible experiments with structured outputs and parameter tracking.

---

## Project Structure

```
.
├── src/
│   └── seasons.jl
├── seasons.conf
├── outputs/
├── Dockerfile
├── Makefile
├── pool.json
├── job.json
├── task.template.json
├── SAS_TOKEN         # (not committed)
```

---

## Output Format

Each run produces:

```
outputs/<timestamp>__<params>/
```

Example:

```
outputs/2026-04-03_11-21-02__N=100__eps=5__lambda=0.25__seed=42/
```

Contents:

* `prices.dat`
* `time`
* `state`
* `seasons.conf`

---

## Local Run

```
make run
```

---

## Docker Run

Build and run:

```
make docker-build
make docker-run
```

Outputs are written to the local `outputs/` directory.

---

## Azure Batch Run

### 1. Login

```
make az-login
```

---

### 2. Create storage container

```
make blob-create
```

---

### 3. Add SAS token

Create a file:

```
SAS_TOKEN
```

Containing only:

```
sp=...&st=...&se=...&sig=...
```

Must include write permissions.

---

### 4. Submit job

```
make submit
```

---

### 5. Monitor

```
make task-show
make task-files
```

---

### 6. Retrieve results

Outputs are uploaded to:

```
results/runs/<job>/<task>/
```

---

## Notes

* Task IDs must be unique within a job
* Job IDs must be unique within the Batch account
* Output paths are structured to avoid collisions
* Uses containerized execution for consistency

---

## Cleanup

```
make nuke
```

---

## Summary

* Same code runs locally, in Docker, and on Azure Batch
* Outputs are reproducible and parameterized
* Minimal setup for scaling experiments

