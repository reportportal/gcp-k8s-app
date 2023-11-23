# Description: Makefile for ReportPortal GCP Marketplace application
registry := gcr.io/$(shell gcloud config get-value project | tr ':' '/')
app_name := reportportal
release_version := $(shell grep 'publishedVersion:' schema.yaml | awk '{print $$2}' | tr -d "'")
release_track := $(shell echo $(release_version) | cut -d '.' -f 1,2)
dependency_chart_version := $(release_version)
deployer_image := $(registry)/$(app_name)/deployer
values_path := tmp/general-values.yaml
cluster_name := rp-mp-test-cluster
cluster_location := us-central1
namespace := test-ns

# Infrastucture images
postgres_gcr_image := $(registry)/$(app_name)/postgresql-11
postgres_repo := bitnami/postgresql
postgres_tag := 11.13.0-debian-10-r12
rabbitmq_gcr_image := $(registry)/$(app_name)/rabbitmq-3
rabbitmq_repo := bitnami/rabbitmq
rabbitmq_tag := 3.10.8-debian-11-r4
opensearch_gcr_image := $(registry)/$(app_name)/opensearch-2
opensearch_repo := opensearchproject/opensearch
opensearch_tag := 2.9.0
minio_gcr_image := $(registry)/$(app_name)/minio-2021
minio_repo := bitnami/minio
minio_tag := 2021.6.17-debian-10-r57

# Default target.
default: build

encode-icon-base64:
	@echo
	@echo "Encoding icon to base64..."
	@echo "data:image/png;base64,$(shell base64 -w 0 assets/icon.png)"

show-versions:
	@echo
	@echo "Release track: $(release_track)"
	@echo "Release version: $(release_version)"
	@echo "Dependency version: $(dependency_chart_version)"
	
# Configures Docker to use gcloud as a credential helper.
configure-docker:
	@echo
	@echo "Configuring Docker to use gcloud as a credential helper..."
	@gcloud auth configure-docker gcr.io --quiet

create-cluster:
	@echo
	@echo "Creating cluster $(cluster_name) in $(cluster_location)..."
	@gcloud container clusters create-auto $(cluster_name) --location=$(cluster_location)
	@kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"
	@kubectl create namespace $(namespace)

# Creates a new Kubernetes namespace called `test-ns` and installs your application into this namespace using `mpdev`.
test-install:
	mpdev install --deployer=$(deployer_image):$(release_version) \
		--parameters='{"name": "$(app_name)", "namespace": "$(namespace)", "reportportal.uat.superadminInitPasswd.password": "erebus"}'

# Verifies that your application is installed correctly.
verify:
	mpdev verify \
  	--deployer=$(deployer_image):$(release_version) \
	--parameters='{"name": "$(app_name)", "namespace": "$(namespace)", "reportportal.uat.superadminInitPasswd.password": "erebus"}'

# Builds a Deployer Docker image and tags it with the name of your Google Cloud Registry.
build:
	@echo
	@echo "Building image $(deployer_image)"
	@helm dependency build chart/reportportal-k8s-app
	@docker build --tag $(deployer_image):$(release_track) .
	@docker tag $(deployer_image):$(release_track) $(deployer_image):$(release_version)

# Pushes a Deployer Docker image to your Google Cloud Registry.
push: build
	@echo
	@echo "Pushing image $(deployer_image)"
	@docker push $(deployer_image):$(release_track)
	@docker push $(deployer_image):$(release_version)

# Publishing used Chart ReportPortal images from Docker Hub to GCR
publish-images: configure-docker
	@echo
	@echo "Getting values from dependency chart..."
	@helm dependency build chart/reportportal-k8s-app
	@helm inspect values ./chart/reportportal-k8s-app/charts/reportportal-$(dependency_chart_version).tgz > $(values_path)
	@echo
	@echo "Running publishing images..."
	-@python scripts/publish-gcr.py \
		--values-path $(values_path) \
		--release-track $(release_track) \
		--release-version $(release_version)

# Publishing used Chart Infrastucture images from Docker Hub to GCR
publish-dependency: configure-docker
	@echo
	@echo "publishing Postgresql..."
	@docker pull $(postgres_repo):$(postgres_tag)
	@docker tag $(postgres_repo):$(postgres_tag) $(postgres_gcr_image):$(release_track)
	@docker tag $(postgres_repo):$(postgres_tag) $(postgres_gcr_image):$(release_version)
	@docker push $(postgres_gcr_image):$(release_track)
	@docker push $(postgres_gcr_image):$(release_version)
	@echo
	@echo "publishing RabbitMQ..."
	@docker pull $(rabbitmq_repo):$(rabbitmq_tag)
	@docker tag $(rabbitmq_repo):$(rabbitmq_tag) $(rabbitmq_gcr_image):$(release_track)
	@docker tag $(rabbitmq_repo):$(rabbitmq_tag) $(rabbitmq_gcr_image):$(release_version)
	@docker push $(rabbitmq_gcr_image):$(release_track)
	@docker push $(rabbitmq_gcr_image):$(release_version)
	@echo
	@echo "publishing OpenSearch..."
	@docker pull $(opensearch_repo):$(opensearch_tag)
	@docker tag $(opensearch_repo):$(opensearch_tag) $(opensearch_gcr_image):$(release_track)
	@docker tag $(opensearch_repo):$(opensearch_tag) $(opensearch_gcr_image):$(release_version)
	@docker push $(opensearch_gcr_image):$(release_track)
	@docker push $(opensearch_gcr_image):$(release_version)
	@echo
	@echo "publishing Minio..."
	@docker pull $(minio_repo):$(minio_tag)
	@docker tag $(minio_repo):$(minio_tag) $(minio_gcr_image):$(release_track)
	@docker tag $(minio_repo):$(minio_tag) $(minio_gcr_image):$(release_version)
	@docker push $(minio_gcr_image):$(release_track)
	@docker push $(minio_gcr_image):$(release_version)

publish: publish-images publish-dependency

push-all: push publish