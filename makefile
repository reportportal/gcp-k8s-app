# Set the registry to your project GCR repo.
registry=gcr.io/$(shell gcloud config get-value project | tr ':' '/')
app_name=reportportal
tag=latest

# Default target.
default: build

# Configures Docker to use gcloud as a credential helper.
configure:
	gcloud auth configure-docker us-docker.pkg.dev

# Builds a Docker image and tags it with the name of your Google Cloud Registry, the app name, and the deployer.
build:
	docker build --tag $(registry)/$(app_name)/deployer:$(tag) .

# Pushes the Docker image to your Google Cloud Registry.
push:
	docker push $(registry)/$(app_name)/deployer:$(tag)

# Creates a new Kubernetes namespace called `test-ns` and installs your application into this namespace using `mpdev`.
test-install:
	kubectl create namespace test-ns
	mpdev install \
		--deployer=$(registry)/$(app_name)/deployer:$(tag) \
		--parameters='{"name": "test-deployment", "namespace": "test-ns"}'
