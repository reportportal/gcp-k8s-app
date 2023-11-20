# Set the registry to your project GCR repo.
registry=gcr.io/$(shell gcloud config get-value project | tr ':' '/')
app_name=reportportal
cluster_name=rp-mp-test-cluster
cluster_location=us-central1
namespace=test-ns
tag=0.1.0

# Default target.
default: build

# Configures Docker to use gcloud as a credential helper.
configure-docker:
	gcloud auth configure-docker gcr.io

create-cluster:
	@gcloud container clusters create-auto $(cluster_name) --location=$(cluster_location)
	@kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"
	@kubectl create namespace $(namespace)

# Builds a Docker image and tags it with the name of your Google Cloud Registry, the app name, and the deployer.
build:
	@helm dependency build chart/reportportal-k8s-app
	@docker build --tag $(registry)/$(app_name)/deployer:$(tag) .

# Pushes the Docker image to your Google Cloud Registry.
push:
	docker push $(registry)/$(app_name)/deployer:$(tag)

# Creates a new Kubernetes namespace called `test-ns` and installs your application into this namespace using `mpdev`.
test-install:
	@mpdev install --deployer=$(registry)/$(app_name)/deployer:$(tag) \
		--parameters='{"name": "$(app_name)", "namespace": "$(namespace)"}'

verify:
	mpdev verify \
  --deployer=$(registry)/$(app_name)/deployer:$(tag)