# Description: Makefile for ReportPortal GCP Marketplace application
registry := gcr.io
app_name := reportportal
gcp_project := $(shell gcloud config get-value project | tr ':' '/')
repository := $(registry)/$(gcp_project)/$(app_name)
release_version := $(shell grep '^version:' data/chart/reportportal-k8s-app/Chart.yaml | awk '{print $$2}')
release_track := $(shell grep '^appVersion:' data/chart/reportportal-k8s-app/Chart.yaml | awk '{print $$2}')
dependency_chart_version := $(shell grep 'version:' data/chart/reportportal-k8s-app/Chart.yaml | tail -n 1 | awk '{print $$2}')
deployer_image := $(repository)/deployer
values_path := $(shell mkdir -p tmp && touch tmp/values.yaml && echo tmp/values.yaml)
cluster_name := rp-mp-test-cluster
cluster_location := us-central1-a
machine_type := custom-4-6144
num_nodes := 3
namespace := test-ns

# Default target.
default: push

show-versions:
	@echo
	@echo "Release track: $(release_track)"
	@echo "Release version: $(release_version)"
	@echo "Dependency version: $(dependency_chart_version)"
	@echo "Deployer image: $(deployer_image)"
	
# Configures Docker to use gcloud as a credential helper.
configure-docker:
	@echo
	@echo "Configuirng Docker to use gcloud as a credential helper..."
	@gcloud auth configure-docker gcr.io --quiet

# Builds a Deployer Docker image and tags it with the name of your Google Cloud Registry.
build: show-versions
	@echo
	@echo "Building image $(deployer_image)"
	@echo dependency update data/chart/reportportal-k8s-app
	@helm dependency build data/chart/reportportal-k8s-app
	@docker build \
		--build-arg REGISTRY=$(repository) \
		--build-arg TAG=$(release_version) \
		--tag $(deployer_image):$(release_track) ./data
	@docker tag $(deployer_image):$(release_track) $(deployer_image):$(release_version)

# Pushes a Deployer Docker image to your Google Cloud Registry.
deploy: configure-docker build
	@echo
	@echo "Pushing deployer image $(deployer_image)"
	@docker push $(deployer_image):$(release_track)
	@docker push $(deployer_image):$(release_version)
	
# Publishing used Chart ReportPortal images from Docker Hub to GCR
deploy-deps: show-versions configure-docker
	@echo
	@echo "Running publishing images..."
	@echo "Getting values from dependency chart..."
	@helm dependency build data/chart/reportportal-k8s-app
	@helm inspect values data/chart/reportportal-k8s-app/charts/reportportal-$(dependency_chart_version).tgz > $(values_path)
	@echo

	@VALUES_PATH=$(values_path) \
		NEW_REGISTRY=$(registry) \
		NEW_REPO=$(gcp_project)/$(app_name) \
		RELEASE_TRACK=$(release_track) \
		RELEASE_VERSION=$(release_version) \
		TARGET_IMAGES=$(TARGET)\
		python scripts/publish-gcr.py

deploy-all: deploy deploy-deps

# Creates a new Kubernetes cluster in your Google Cloud project.
create-test-cluster:
	@echo
	@echo "Creating cluster $(cluster_name) in $(cluster_location)..."
	@gcloud container clusters create $(cluster_name) \
		--location=$(cluster_location) \
		--machine-type=${machine_type} \
		--num-nodes=${num_nodes}
	@echo
	@echo "Add the application support CRD to the cluster..."
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