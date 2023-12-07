# Description: Makefile for ReportPortal GCP Marketplace application
registry := gcr.io/$(shell gcloud config get-value project | tr ':' '/')
app_name := reportportal
release_version := $(shell grep '^version:' chart/reportportal-k8s-app/Chart.yaml | awk '{print $$2}')
release_track := $(shell echo $(release_version) | cut -d '.' -f 1,2)
dependency_chart_version := $(shell grep 'version:' chart/reportportal-k8s-app/Chart.yaml | tail -n 1 | awk '{print $$2}')
deployer_image := $(registry)/$(app_name)/deployer
values_path := tmp/general-values.yaml
cluster_name := rp-mp-test-cluster
cluster_location := us-central1
namespace := test-ns

# Infrastucture images
postgres_origin_image := bitnami/postgresql:11.22.0
postgres_rp_gcr_image := $(registry)/$(app_name)/postgresql11
rabbitmq_origin_image := bitnami/rabbitmq:3.10.25
rabbitmq_rp_gcr_image := $(registry)/$(app_name)/rabbitmq3
opensearch_origin_image := opensearchproject/opensearch:2.11.1
opensearch_rp_gcr_image := $(registry)/$(app_name)/opensearch2
minio_origin_image := bitnami/minio:2023.11.20
minio_rp_gcr_image := $(registry)/$(app_name)/minio2023

# Default target.
default: push

show-versions:
	@echo
	@echo "Release track: $(release_track)"
	@echo "Release version: $(release_version)"
	@echo "Dependency version: $(dependency_chart_version)"
	
# Configures Docker to use gcloud as a credential helper.
configure-docker:
	@echo
	@echo "Configuirng Docker to use gcloud as a credential helper..."
	@gcloud auth configure-docker gcr.io --quiet

# Creates a new Kubernetes cluster in your Google Cloud project.
create-cluster:
	@echo
	@echo "Creating cluster $(cluster_name) in $(cluster_location)..."
	@gcloud container clusters create-auto $(cluster_name) --location=$(cluster_location)
	@kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"
	@kubectl create namespace $(namespace)

# Creates a new Kubernetes namespace called `test-ns` and installs your application into this namespace using `mpdev`.
test-install:
	mpdev install --deployer=$(deployer_image):$(release_version) \
		--parameters='{"name": "$(app_name)", "namespace": "$(namespace)"}'

# Verifies that your application is installed correctly.
verify:
	mpdev verify \
  	--deployer=$(deployer_image):$(release_version) \
	--wait_timeout=1800

# Builds a Deployer Docker image and tags it with the name of your Google Cloud Registry.
build: show-versions
	@echo
	@echo "Building image $(deployer_image)"
	@helm dependency build chart/reportportal-k8s-app
	@docker build \
		--build-arg REGISTRY=$(registry)/$(app_name) \
		--build-arg TAG=$(release_version) \
		--tag $(deployer_image):$(release_track) .
	@docker tag $(deployer_image):$(release_track) $(deployer_image):$(release_version)

# Pushes a Deployer Docker image to your Google Cloud Registry.
push: configure-docker build
	@echo
	@echo "Pushing image $(deployer_image)"
	@docker push $(deployer_image):$(release_track)
	@docker push $(deployer_image):$(release_version)

# Publishing used Chart ReportPortal images from Docker Hub to GCR
publish-images: show-versions configure-docker
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
	@docker pull $(postgres_origin_image)
	@docker tag $(postgres_origin_image) $(postgres_rp_gcr_image):$(release_track)
	@docker tag $(postgres_origin_image) $(postgres_rp_gcr_image):$(release_version)
	@docker push $(postgres_rp_gcr_image):$(release_track)
	@docker push $(postgres_rp_gcr_image):$(release_version)
	@echo
	@echo "publishing RabbitMQ..."
	@docker pull $(rabbitmq_origin_image)
	@docker tag $(rabbitmq_origin_image) $(rabbitmq_rp_gcr_image):$(release_track)
	@docker tag $(rabbitmq_origin_image) $(rabbitmq_rp_gcr_image):$(release_version)
	@docker push $(rabbitmq_rp_gcr_image):$(release_track)
	@docker push $(rabbitmq_rp_gcr_image):$(release_version)
	@echo
	@echo "publishing OpenSearch..."
	@docker pull $(opensearch_origin_image)
	@docker tag $(opensearch_origin_image) $(opensearch_rp_gcr_image):$(release_track)
	@docker tag $(opensearch_origin_image) $(opensearch_rp_gcr_image):$(release_version)
	@docker push $(opensearch_rp_gcr_image):$(release_track)
	@docker push $(opensearch_rp_gcr_image):$(release_version)
	@echo
	@echo "publishing Minio..."
	@docker pull $(minio_origin_image)
	@docker tag $(minio_origin_image) $(minio_rp_gcr_image):$(release_track)
	@docker tag $(minio_origin_image) $(minio_rp_gcr_image):$(release_version)
	@docker push $(minio_rp_gcr_image):$(release_track)
	@docker push $(minio_rp_gcr_image):$(release_version)

publish-all: push publish-images publish-dependency