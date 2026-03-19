# ===== User-configurable variables =====

SUBSCRIPTION_ID := bac2f3e8-ad6d-48ec-870c-27a2629381b5
RESOURCE_GROUP  := pspauction
BATCH_ACCOUNT   := jauction
STORAGE_ACCOUNT := jauctionblob
BLOB_CONTAINER  := results

POOL_ID := julia-pool
JOB_ID  := julia-job
TASK_ID := run-seasons

DOCKER_USER := jkblazek
IMAGE_NAME  := seasons-auction
IMAGE_TAG   := latest
IMAGE       := $(DOCKER_USER)/$(IMAGE_NAME):$(IMAGE_TAG)

CONF_FILE := seasons.conf
NPROC := 8
export OPENBLAS_NUM_THREADS=$(NPROC)

# Optional: set this after generating a SAS URL
CONTAINER_URL ?= https://jauctionblob.blob.core.windows.net/results?<SAS_TOKEN>

# ===== Local Julia =====

.PHONY: run
run:
	julia -t$(NPROC) src/seasons.jl

.PHONY: clean
clean:
	rm -rf prices.dat time state outputs

# ===== Docker =====

.PHONY: docker-build
docker-build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

.PHONY: docker-test
docker-test:
	docker run --rm -v "$$(pwd)/outputs:/app/outputs" $(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: docker-tag
docker-tag:
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE)

.PHONY: docker-push
docker-push: docker-tag
	docker push $(IMAGE)

# ===== Azure auth / setup =====

.PHONY: az-login
az-login:
	az login
	az account set --subscription $(SUBSCRIPTION_ID)
	az batch account login -g $(RESOURCE_GROUP) -n $(BATCH_ACCOUNT)

.PHONY: blob-create
blob-create:
	az storage container create \
		--account-name $(STORAGE_ACCOUNT) \
		--name $(BLOB_CONTAINER) \
		--auth-mode login

# ===== Batch resources =====

.PHONY: pool
pool:
	az batch pool create --json-file pool.json

.PHONY: job
job:
	az batch job create --json-file job.json

.PHONY: task
task:
	az batch task create --job-id $(JOB_ID) --json-file task.json

.PHONY: submit
submit: pool job task

# ===== Monitoring =====

.PHONY: task-show
task-show:
	az batch task show --job-id $(JOB_ID) --task-id $(TASK_ID)

.PHONY: task-files
task-files:
	az batch task file list --job-id $(JOB_ID) --task-id $(TASK_ID)

# ===== Cleanup Azure Batch objects =====

.PHONY: delete-task
delete-task:
	-az batch task delete --job-id $(JOB_ID) --task-id $(TASK_ID) --yes

.PHONY: delete-job
delete-job:
	-az batch job delete --job-id $(JOB_ID) --yes

.PHONY: delete-pool
delete-pool:
	-az batch pool delete --pool-id $(POOL_ID) --yes

.PHONY: nuke
nuke: delete-task delete-job delete-pool

# ===== End-to-end helpers =====

.PHONY: local-test
local-test: clean run

.PHONY: docker-all
docker-all: docker-build docker-test

.PHONY: azure-all
azure-all: az-login submit

