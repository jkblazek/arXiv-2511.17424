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
CONTAINER_URL = https://jauctionblob.blob.core.windows.net/results?sv=$(SAS_TOKEN)


run:
	ts=$(date +"%Y-%m-%d_%H-%M-%S")
	tag=$(grep -E '^(N|eps|lambda|seed)=' seasons.conf | tr '\n' '_' | sed 's/_$//' | sed 's/_/__/g')
	outdir=outputs/$${ts}__$${tag}
	mkdir -p "$outdir"

	julia -t$(NPROC) src/seasons.jl
	mv prices.dat time state "$outdir"/ 2>/dev/null || true
	cp seasons.conf "$outdir"

clean:
	rm -rf outputs

save:
	ts=$(date +"%Y-%m-%d_%H-%M-%S")
	outdir="../$ts"
	mkdir -p "$outdir"
	mv outputs "$outdir"


docker: docker-build docker-tag docker-push docker-run

docker-build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

docker-run:
	mkdir -p outputs
	docker run --rm \
		-v "$$(pwd)/outputs:/app/outputs" \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		/bin/bash -c 'ts=$$(date +"%Y-%m-%d_%H-%M-%S"); \
		tag=$$(grep -E "^(N|eps|lambda|seed)=" seasons.conf | tr "\n" "_" | sed "s/_$$//" | sed "s/_/__/g"); \
		outdir=outputs/$${ts}__$${tag}; \
		mkdir -p "$$outdir"; \
		julia -t$(NPROC) src/seasons.jl; \
		cp -r prices.dat time state "$$outdir"/ 2>/dev/null || true'

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

task-json:
	sed "s|__SAS_TOKEN__|$(SAS_TOKEN)|g" task.template.json > task.json

task: task-json
	az batch task create --job-id $(JOB_ID) --json-file task.json

task:
	az batch task create --job-id $(JOB_ID) --json-file task.json

submit: pool job task

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


