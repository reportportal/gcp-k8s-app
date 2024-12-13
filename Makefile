# Description: Makefile for ReportPortal GCP Marketplace application
registry := gcr.io
app_name := reportportal
gcp_project := epam-mp-rp
repository := $(registry)/$(gcp_project)/$(app_name)
release_version := $(shell yq e '.appVersion' data/chart/reportportal-k8s-app/Chart.yaml)
release_track := $(shell echo $(release_version) | cut -d. -f1,2)
dependency_chart_version := $(shell yq e '.version' data/chart/reportportal-k8s-app/Chart.yaml)
deployer_image := $(repository)/deployer
values_path := $(shell mkdir -p tmp && touch tmp/values.yaml && echo tmp/values.yaml)
cluster_name := rp-mp-test-cluster
cluster_location := us-central1-a
machine_type := custom-4-6144
num_nodes := 3
namespace := test-ns

# Deploy all images to GCR.
default: deploy-all

info:
	@ echo
	@ echo "Release track: $(release_track)"
	@ echo "Release version: $(release_version)"
	@ echo "Dependency version: $(dependency_chart_version)"
	@ echo "Deployer image: $(deployer_image)"

# Configures Docker to use gcloud as a credential helper.
configure:
	@ echo
	@ echo "Configuring Docker to use gcloud as a credential helper..."
	@ gcloud auth configure-docker gcr.io --quiet

# Builds a Deployer Docker image and tags it with the name of your Google Cloud Registry.
deploy: info
	@ echo
	@ echo "Building image $(deployer_image)"
	@ helm repo add reportportal https://reportportal.io/kubernetes
	@ helm dependency update data/chart/reportportal-k8s-app
	@ helm dependency build data/chart/reportportal-k8s-app
	@ docker build\
		--tag $(deployer_image):$(release_track) \
		--tag $(deployer_image):$(release_version) \
		--build-arg REGISTRY=$(repository) \
		--build-arg TAG=$(release_version) \
		--push \
		./data
	@ crane mutate -a "com.googleapis.cloudmarketplace.product.service.name=reportportal.endpoints.epam-mp-rp.cloud.goog" $(deployer_image):$(release_track)
	@ crane mutate -a "com.googleapis.cloudmarketplace.product.service.name=reportportal.endpoints.epam-mp-rp.cloud.goog" $(deployer_image):$(release_version)

deploy-deps: info configure
	@ echo
	@ echo "Running publishing images..."
	@ echo "Getting values from dependency chart..."
	@ helm dependency build data/chart/reportportal-k8s-app
	@ helm inspect values data/chart/reportportal-k8s-app/charts/reportportal-$(dependency_chart_version).tgz > $(values_path)
	@ echo
	@ VALUES_PATH=$(values_path) \
		NEW_REGISTRY=$(registry) \
		NEW_REPO=$(gcp_project)/$(app_name) \
		RELEASE_TRACK=$(release_track) \
		RELEASE_VERSION=$(release_version) \
		TARGET_IMAGES=$(TARGET)\
		python scripts/publish-gcr.py

# Deploys deployer image and dependence's images ti GCR.
deploy-all: deploy deploy-deps

# Creates a new Kubernetes cluster in your Google Cloud project.
test-cluster:
	@ echo
	@ echo "Creating cluster $(cluster_name) in $(cluster_location)..."
	@ gcloud container clusters create $(cluster_name) \
		--location=$(cluster_location) \
		--machine-type=${machine_type} \
		--num-nodes=${num_nodes}
	@ echo
	@ echo "Add the application support CRD to the cluster..."
	@ kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"
	@ kubectl create namespace $(namespace)

# Creates a new Kubernetes namespace called `test-ns` and installs your application into this namespace using `mpdev`.
test-install:
	mpdev install --deployer=$(deployer_image):$(release_version) \
		--parameters='{"name": "$(app_name)", "namespace": "$(namespace)"}'

# Verifies that your application is installed correctly.
verify:
	mpdev verify \
	--deployer=$(deployer_image):$(release_version) \
	--wait_timeout=1800 \
	--parameters='{"name": "$(app_name)", "namespace": "$(namespace)", "reportportal.ingress.hosts":"gcp.docs.reportportal.io", "reportportal.ingress.tls.certificate.gcpManaged":true}'

clean-cluster: 
	@ echo
	@ echo "Cleaning up the cluster..."
	@ gcloud container clusters delete $(cluster_name) --location=$(cluster_location) --quiet

clean-disks:
	@ echo
	@ echo "Clearing all disks..."
    @ gcloud compute disks list --filter="zones:($(cluster_location))" --format="value(name)" | xargs -I {} gcloud compute disks delete {} --zone=$(cluster_location) --quiet

clean: clean-cluster clean-disks
