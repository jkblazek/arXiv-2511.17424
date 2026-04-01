
CONF_FILE := seasons.conf
NPROC := 8
export OPENBLAS_NUM_THREADS=$(NPROC)

# ===== Local Julia =====

run:
	julia -t$(NPROC) src/seasons.jl

clean:
	rm -rf prices.dat time state outputs

# ===== Docker =====

DOCKER_USER := jkblazek
IMAGE_NAME  := seasons-auction
IMAGE_TAG   := latest
IMAGE       := $(DOCKER_USER)/$(IMAGE_NAME):$(IMAGE_TAG)

docker-run:
	mkdir -p outputs
	docker run --rm -v "$$(pwd)/outputs:/app/outputs" $(IMAGE_NAME):$(IMAGE_TAG) /bin/bash -lc 'julia -t$(NPROC) src/seasons.jl && cp -r prices.dat time state outputs/ 2>/dev/null || true'

docker-build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

docker-test:
	docker run --rm -v "$$(pwd)/outputs:/app/outputs" $(IMAGE_NAME):$(IMAGE_TAG)

docker-tag:
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE)

docker-push: docker-tag
	docker push $(IMAGE)

# ===== Azure auth / setup =====

SUBSCRIPTION_ID := bac2f3e8-ad6d-48ec-870c-27a2629381b5
RESOURCE_GROUP  := pspauction
BATCH_ACCOUNT   := jauction
STORAGE_ACCOUNT := jauctionblob
BLOB_CONTAINER  := results

POOL_ID := julia-pool
JOB_ID  := julia-job
TASK_ID := run-seasons

# Optional: set this after generating a SAS URL
CONTAINER_URL ?= https://jauctionblob.blob.core.windows.net/results?<SAS_TOKEN>

az-login:
	az login
	az account set --subscription $(SUBSCRIPTION_ID)
	az batch account login -g $(RESOURCE_GROUP) -n $(BATCH_ACCOUNT)

blob-create:
	az storage container create \
		--account-name $(STORAGE_ACCOUNT) \
		--name $(BLOB_CONTAINER) \
		--auth-mode login

# ===== Batch resources =====

pool:
	az batch pool create --json-file pool.json

job:
	az batch job create --json-file job.json

task:
	az batch task create --job-id $(JOB_ID) --json-file task.json

submit: pool job task

# ===== Monitoring =====

task-show:
	az batch task show --job-id $(JOB_ID) --task-id $(TASK_ID)

task-files:
	az batch task file list --job-id $(JOB_ID) --task-id $(TASK_ID)

# ===== Cleanup Azure Batch objects =====

delete-task:
	-az batch task delete --job-id $(JOB_ID) --task-id $(TASK_ID) --yes

delete-job:
	-az batch job delete --job-id $(JOB_ID) --yes

delete-pool:
	-az batch pool delete --pool-id $(POOL_ID) --yes

nuke: delete-task delete-job delete-pool

# ===== End-to-end helpers =====

local-test: clean run

docker-all: docker-build docker-test

azure-all: az-login submit

