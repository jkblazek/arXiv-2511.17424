CONF_FILE := seasons.conf
NPROC := 8
export OPENBLAS_NUM_THREADS=$(NPROC)

DOCKER_USER := jkblazek
IMAGE_NAME  := seasons-auction
IMAGE_TAG   := latest
IMAGE       := $(DOCKER_USER)/$(IMAGE_NAME):$(IMAGE_TAG)

SUBSCRIPTION_ID := bac2f3e8-ad6d-48ec-870c-27a2629381b5
RESOURCE_GROUP  := pspauction
BATCH_ACCOUNT   := jauction
STORAGE_ACCOUNT := jauctionblob
BLOB_CONTAINER  := results

POOL_ID := julia-pool
JOB_ID  := julia-job
TASK_ID := run-seasons

SAS_TOKEN := $(shell cat SAS_TOKEN 2>/dev/null)
CONTAINER_URL = https://jauctionblob.blob.core.windows.net/results?$(SAS_TOKEN)
SAS_URL := $(shell cat SAS_URL 2>/dev/null)
OUT_DIR := outputs/$(shell date +"%Y-%m-%d_%H-%M-%S")__$(shell \
	grep -E '^(N|eps|lambda|seed)=' seasons.conf | \
	tr '\n' '_' | sed 's/_$$//' | sed 's/_/__/g')

.PHONY: run-local clean \
		make-remote run-remote \
        task-show task-files \
        nuke

out-dir:
	echo $(OUT_DIR) > OUT_DIR
	mkdir -p $(OUT_DIR)

run-local: out-dir
	julia -t$(NPROC) src/seasons.jl
	mv prices.dat time state $(OUT_DIR)/ 2>/dev/null || true
	cp seasons.conf $(OUT_DIR)

clean:
	rm -rf outputs

docker-build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

docker-run: out-dir
	docker run --rm \
		-v "$$(pwd)/outputs:/app/outputs" \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		/bin/bash -c 'outdir=$$(cat OUT_DIR);\
		mkdir -p "$$outdir"; \
		julia -t$(NPROC) src/seasons.jl; \
		cp -r prices.dat time state "$$outdir"/ 2>/dev/null || true'
	cp seasons.conf $(OUT_DIR)

docker-tag:
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE)

docker-push: docker-tag
	docker push $(IMAGE)

az-login:
	az login
	az account set --subscription $(SUBSCRIPTION_ID)
	az batch account login -g $(RESOURCE_GROUP) -n $(BATCH_ACCOUNT)

blob-create:
	az storage container create \
		--account-name $(STORAGE_ACCOUNT) \
		--name $(BLOB_CONTAINER) \
		--auth-mode login 

pool:
	az batch pool create --json-file pool.json

job:
	az batch job create --json-file job.json

task-json: out-dir
	python3 -c 'from pathlib import Path; url = Path("SAS_URL").read_text().strip(); template = Path("task.template.json").read_text(); Path("task.json").write_text(template.replace("__SAS_URL__", url))'
	python3 -c 'from pathlib import Path; outdir = Path("OUT_DIR").read_text().strip(); template = Path("task.json").read_text(); Path("task.json").write_text(template.replace("__OUT_DIR__", outdir))'

task: task-json
	az batch task create --job-id $(JOB_ID) --json-file task.json

submit: pool job task

make-remote: docker-build docker-tag docker-push

run-remote: make-remote az-login blob-create submit

task-show:
	az batch task show --job-id $(JOB_ID) --task-id $(TASK_ID)

task-files:
	az batch task file list --job-id $(JOB_ID) --task-id $(TASK_ID)

delete-task:
	-az batch task delete --job-id $(JOB_ID) --task-id $(TASK_ID) --yes

delete-job:
	-az batch job delete --job-id $(JOB_ID) --yes

delete-pool:
	-az batch pool delete --pool-id $(POOL_ID) --yes

nuke: delete-task delete-job delete-pool


