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
JOB_ID  := julia-job-$(shell date +"%Y-%m-%d_%H-%M")
TASK_ID := run-seasons-$(shell date +"%Y-%m-%d_%H-%M-%S")

SAS_TOKEN := $(shell cat SAS_TOKEN 2>/dev/null)
CONTAINER_URL = https://jauctionblob.blob.core.windows.net/results?$(SAS_TOKEN)
SAS_URL := $(shell cat SAS_URL 2>/dev/null)
OUT_DIR := $(shell date +"%Y-%m-%d_%H-%M-%S")__$(shell \
	grep -E '^(N|eps|lambda|seed)=' seasons.conf | \
	tr '\n' '_' | sed 's/_$$//' | sed 's/_/__/g')

.PHONY: clean \
		make-remote run-remote \
        task-show task-files \
		freelunch oneauct seasons \
        nuke

tag-task:
	echo $(TASK_ID) > TASK_ID
	echo $(OUT_DIR) > OUT_DIR
	
tag-job:
	echo $(JOB_ID) > JOB_ID

oneauct: 
	mkdir -p outputs/$(OUT_DIR)
	julia -t$(NPROC) src/oneauct.jl
	mv prices.dat time state outputs/$(OUT_DIR)/ 2>/dev/null || true
	cp oneauct.conf outputs/$(OUT_DIR)

freelunch: 
	mkdir -p outputs/$(OUT_DIR)
	julia -t$(NPROC) src/freelunch.jl
	mv prices.dat time state outputs/$(OUT_DIR)/ 2>/dev/null || true
	cp seasons.conf outputs/$(OUT_DIR)

seasons: 
	mkdir -p outputs/$(OUT_DIR)
	julia -t$(NPROC) src/seasons.jl
	mv prices.dat time state outputs/$(OUT_DIR)/ 2>/dev/null || true
	cp seasons.conf outputs/$(OUT_DIR)

clean:
	rm -rf outputs

docker-build: 
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

docker-run: 
	mkdir -p outputs
	docker run --rm \
		-e OUT_DIR="$(OUT_DIR)" \
		-v "$$(pwd)/outputs:/app/outputs" \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		/bin/bash -c 'mkdir -p outputs/"$$OUT_DIR"; cp seasons.conf outputs/"$$OUT_DIR"; julia -t$(NPROC) src/seasons.jl; mv prices.dat time state outputs/"$$OUT_DIR"/ 2>/dev/null || true'

docker-tag:
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE)

docker-push: docker-tag
	docker push $(IMAGE)

make-remote: docker-build docker-tag docker-push

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

job-json: tag-job
	python3 -c 'from pathlib import Path; jobid = Path("JOB_ID").read_text().strip(); template = Path("job.template.json").read_text(); Path("job.json").write_text(template.replace("__JOB_ID__", jobid))'

job: job-json
	az batch job create --json-file job.json

task-json: tag-task
	python3 -c 'from pathlib import Path; url = Path("SAS_URL").read_text().strip(); template = Path("task.template.json").read_text(); Path("task.json").write_text(template.replace("__SAS_URL__", url))'
	python3 -c 'from pathlib import Path; outdir = Path("OUT_DIR").read_text().strip(); template = Path("task.json").read_text(); Path("task.json").write_text(template.replace("__OUT_DIR__", outdir))'
	python3 -c 'from pathlib import Path; taskid = Path("TASK_ID").read_text().strip(); template = Path("task.json").read_text(); Path("task.json").write_text(template.replace("__TASK_ID__", taskid))'
	python3 -c 'from pathlib import Path; jobid = Path("JOB_ID").read_text().strip(); template = Path("task.json").read_text(); Path("task.json").write_text(template.replace("__JOB_ID__", jobid))'

task: task-json
	az batch task create --job-id $(shell cat JOB_ID 2>/dev/null) --json-file task.json

task-show:
	az batch task show --job-id $(shell cat JOB_ID 2>/dev/null) --task-id $(shell cat TASK_ID 2>/dev/null)

task-list:
	az batch task list --job-id julia-job

task-files:
	az batch task file list --job-id $(shell cat JOB_ID 2>/dev/null) --task-id $(shell cat TASK_ID 2>/dev/null)

delete-task:
	-az batch task delete --job-id $(shell cat JOB_ID 2>/dev/null) --task-id $(shell cat TASK_ID 2>/dev/null) --yes

delete-job:
	-az batch job delete --job-id $(shell cat JOB_ID 2>/dev/null) --yes

delete-pool:
	-az batch pool delete --pool-id $(POOL_ID) --yes

nuke: delete-task delete-job delete-pool

submit: pool job task

run-remote: az-login blob-create submit
