# arXiv-2511.17424
The Effects of Latency on a Progressive Second-Price Auction
------------------------------------------------------------


This repository contains the simulation framework used in:

https://arxiv.org/abs/2511.17424

It implements a dynamic, networked auction model based on the **Progressive Second Price (PSP)** mechanism, with a focus on **asynchronous updates, latency, and market stability**.

---

## Overview

Modern decentralized markets operate under **partial information and communication delays**.
This project studies how **latency influences convergence, price formation, and allocation dynamics** in PSP auctions.

The simulation models:

* Buyers and sellers as interacting agents
* Iterative bid updates under PSP rules
* Asynchronous execution with delay (latency)
* Market evolution over time

---

## Key Concepts

### Progressive Second Price (PSP)

PSP is an extension of second-price auctions to distributed settings:

* Buyers submit bids across multiple sellers
* Allocation evolves iteratively
* Prices reflect **externality (exclusion–compensation)** rather than direct bids
* Truthfulness emerges through **ε-best responses**

---

### Latency

Latency is modeled as:

* Delayed bid updates
* Asynchronous arrival of information
* Non-synchronized agent behavior

This introduces:

* transient instability
* delayed convergence
* oscillatory or phase-shifted price dynamics

---

### Networked Market Structure

The market is a **bipartite graph**:

* Buyers ↔ Sellers
* Shared sellers induce **buyer–buyer influence**
* Market behavior propagates through connectivity

---

## What This Code Does

The simulation:

* evolves a PSP auction over time
* tracks allocation and price dynamics
* outputs time-series data for analysis

## Research Context

This code supports analysis of:

* convergence under asynchronous updates
* impact of latency on equilibrium behavior
* propagation of influence through network structure
* stability vs. oscillation in distributed auctions

The broader framework connects:

* auction theory
* game theory
* network dynamics
* distributed systems

---

## Notes

* Azure tasks must have unique IDs
* SAS tokens must include write permissions
* Outputs are written to task-local storage and uploaded post-run

---

## Future Work

* multi-task parameter sweeps (parallel experiments)
* latency distribution modeling (e.g., Weibull)
* visualization pipeline (price variance, convergence metrics)
* integration with network topology experiments

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

