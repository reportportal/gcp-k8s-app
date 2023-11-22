# Set the registry to your project GCR repo.
registry := gcr.io/$(shell gcloud config get-value project | tr ':' '/')
app_name := reportportal
release_track := 0.1
release_version := 0.1.0
deployer_image := $(registry)/$(app_name)/deployer
cluster_name := rp-mp-test-cluster
cluster_location := us-central1
namespace := test-ns
values_path := chart/reportportal/values.yaml

# Default target.
default: build

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

# Builds a Deployer Docker image and tags it with the name of your Google Cloud Registry.
build:
	@echo
	@echo "Building image $(deployer_image)"
	@helm dependency build chart/reportportal-k8s-app
	@docker build --tag $(deployer_image):$(release_track) .
	@docker tag $(deployer_image):$(release_track) $(deployer_image):$(release_version)

# Pushes the Docker image to your Google Cloud Registry.
push: build
	@echo
	@echo "Pushing image $(deployer_image)"
	@docker push $(deployer_image):$(release_track)
	@docker push $(deployer_image):$(release_version)

# Creates a new Kubernetes namespace called `test-ns` and installs your application into this namespace using `mpdev`.
test-install:
	mpdev install --deployer=$(deployer_image) \
		--parameters='{"name": "$(app_name)", "namespace": "$(namespace)", "uat.superadminInitPasswd.password": "erebus"}'

# Verifies that your application is installed correctly.
verify:
	mpdev verify \
  	--deployer=$(deployer_image) \
	--parameters='{"name": "$(app_name)", "namespace": "$(namespace)", "reportportal.uat.superadminInitPasswd.password": "erebus"}'

# Transferring used Chart images from Docker Hub to GCR
transfer-images: configure-docker
	@echo
	@echo "Running helm fetch..."
	-@helm fetch --untar --destination chart oci://us-docker.pkg.dev/epam-mp-rp/reportportal/reportportal
	@echo
	@echo "Running transfer images..."
	-@python scripts/transfer-images.py \
		--values-path $(values_path)

transfer-dependency: configure-docker
	@echo
	@echo "Transferring Postgresql..."
	postgres_gcr_image := $(registry)/$(app_name)/postgresql-$(postgres_tag)
	@docker pull $(postgres_repo):$(postgres_tag)
	@docker tag $(postgres_repo):$(postgres_tag) $(postgres_gcr_image):$(release_track)
	@docker tag $(postgres_repo):$(postgres_tag) $(postgres_gcr_image):$(release_version)
	@docker push $(postgres_gcr_image):$(release_track)
	@docker push $(postgres_gcr_image):$(release_version)
	@echo
	@echo "Transferring RabbitMQ..."
	rabbitmq_gcr_image := $(registry)/$(app_name)/rabbitmq-$(rabbitmq_tag)
	@docker pull $(rabbitmq_repo):$(rabbitmq_tag)
	@docker tag $(rabbitmq_repo):$(rabbitmq_tag) $(rabbitmq_gcr_image):$(release_track)
	@docker tag $(rabbitmq_repo):$(rabbitmq_tag) $(rabbitmq_gcr_image):$(release_version)
	@docker push $(rabbitmq_gcr_image):$(release_track)
	@docker push $(rabbitmq_gcr_image):$(release_version)
	@echo
	@echo "Transferring OpenSearch..."
	opensearch_gcr_image := $(registry)/$(app_name)/opensearch-$(opensearch_tag)
	@docker pull $(opensearch_repo):$(opensearch_tag)
	@docker tag $(opensearch_repo):$(opensearch_tag) $(opensearch_gcr_image):$(release_track)
	@docker tag $(opensearch_repo):$(opensearch_tag) $(opensearch_gcr_image):$(release_version)
	@docker push $(opensearch_gcr_image):$(release_track)
	@docker push $(opensearch_gcr_image):$(release_version)
	@echo
	@echo "Transferring Minio..."
	minio_gcr_image := $(registry)/$(app_name)/minio-$(minio_tag)
	@docker pull $(minio_repo):$(minio_tag)
	@docker tag $(minio_repo):$(minio_tag) $(minio_gcr_image):$(release_track)
	@docker tag $(minio_repo):$(minio_tag) $(minio_gcr_image):$(release_version)
	@docker push $(minio_gcr_image):$(release_track)
	@docker push $(minio_gcr_image):$(release_version)

transfer: transfer-images transfer-dependency

push-all: push transfer