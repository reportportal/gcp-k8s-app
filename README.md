# gcp-k8s-app

ReportPortal Kubrentes repository wrapper for Google Cloud Platform Marketplace

## Overview

ReportPortal is a web-based test automation dashboard that aggregates test results from
different test frameworks and provides tools for quick analysis and reporting.

## Installation

### Quick install with Google Cloud Marketplace

Install ReportPortal to a Google Kubernetes Engine cluster using Google Cloud Marketplace by following [the on-screen instructions](https://console.cloud.google.com/marketplace/product/epam-mp-rp/reportportal).

### Command-line instructions

#### Prerequisites

##### Setting up command-line tools

You'll need the following tools:

* [gcloud](https://cloud.google.com/sdk/gcloud/) - Google Cloud SDK
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) - Kubernetes command-line tool
* [docker](https://docs.docker.com/get-docker/) - Docker command-line tool
* [git](https://git-scm.com/downloads) - Git command-line tool
* [openssl](https://www.openssl.org/) - OpenSSL command-line tool
* [helm](https://helm.sh/docs/intro/install/) - Helm command-line tool

Configure gcloud as a Docker credential helper:

```bash
gcloud auth configure-docker
```

##### Creating a Google Kubernetes Engine cluster

Create a Google Kubernetes Engine cluster with the following command:

```bash
export CLUSTER=reportportal-cluster
export ZONE=us-central1-a

gcloud container clusters create ${CLUSTER} \
    --zone=${ZONE} \
    --machine-type=e2-standard-2 --num-nodes=3
```

Configure kubectl to connect to the new cluster:

```bash
gcloud container clusters get-credentials ${CLUSTER} --zone ${ZONE}
```

#### Installing the Application resource definition

An Application resource is a collection of individual Kubernetes components, such as Services, StatefulSets, and so on, that you can manage as a group.

To set up your cluster to understand Application resources, run the following command:

```bash
kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"
```

You need to run this command once.

> **Note**: The Application resource is defined by the [Kubernetes SIG-apps community](https://github.com/kubernetes/community/tree/master/sig-apps).
> You can find the source code at [GitHub Application repo](http://github.com/kubernetes-sigs/application).

### Installing the Application

Navigate to the data directory:

```bash
cd data
```

#### Configuring environment variables

Set the following environment variables:

```bash
export APP_INSTANCE_NAME=reportportal
export NAMESPACE=default
```

Choose the application image tag:

```bash
export TAG=23.2
```

Configure the container images:

```bash
export IMAGE_REPO_API=eu.gcr.io/epam-mp-rp/reportportal/reportportal-api
export IMAGE_REPO_INDEX=eu.gcr.io/epam-mp-rp/reportportal/reportportal-index
export IMAGE_REPO_UI=eu.gcr.io/epam-mp-rp/reportportal/reportportal-ui
export IMAGE_REPO_UAT=eu.gcr.io/epam-mp-rp/reportportal/reportportal-uat
export IMAGE_REPO_JOBS=eu.gcr.io/epam-mp-rp/reportportal/reportportal-jobs
export IMAGE_REPO_ANALYZER=eu.gcr.io/epam-mp-rp/reportportal/reportportal-analyzer
export IMAGE_REPO_METRICGATHERER=eu.gcr.io/epam-mp-rp/reportportal/reportportal-metricsgatherer
export IMAGE_REPO_MIGRATOR=eu.gcr.io/epam-mp-rp/reportportal-migrator
export IMAGE_REGISTRY_DB=eu.gcr.io
export IMAGE_REPO_DB=epam-mp-rp/reportportal/postgresql11
export IMAGE_REGISTRY_RABBITMQ=eu.gcr.io
export IMAGE_REPO_RABBITMQ=epam-mp-rp/reportportal/rabbitmq3
export IMAGE_REPO_OS=eu.gcr.io/epam-mp-rp/reportportal/opensearch2
export IMAGE_REGISTRY_BLOB=eu.gcr.io
export IMAGE_REPO_BLOB=epam-mp-rp/reportportal/minio2023
export IMAGE_REPO_INIT=eu.gcr.io/epam-mp-rp/reportportal/k8s-wait-for
```

> **Note**: You can find the list of available tags at [Google Container Registry](https://console.cloud.google.com/gcr/images/epam-mp-rp/global/reportportal).

Set or generate password for superadmin initial user:

```bash
alias generate_pwd="cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1 | tr -d '\n'"

export SUPERADMIN_PASSWORD=$(generate_pwd)
```

#### (Optional) Creating a Transport Layer Security (TLS) certificate

You can use a self-signed TLS certificate or a certificate from a certificate authority.

```bash
unset DOMAIN_NAME
export SSL_CONFIGURATION="Self-signed"
```

If you already have a certificate that you want to use, copy your certificate and key pair to the /tmp/tls.crt and /tmp/tls.key files, respectively, then skip to the next step.

To create a new certificate, run the following command:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /tmp/tls.key \
    -out /tmp/tls.crt \
    -subj "/CN=reportportal/O=reportportal"
```

Set key and certificate values:

```bash
export TLS_CERTIFICATE_KEY="$(cat /tmp/tls.key | base64)"
export TLS_CERTIFICATE_CRT="$(cat /tmp/tls.crt | base64)"
```

#### Creating a namespace

Create a namespace for the application:

```bash
kubectl create namespace ${NAMESPACE}
```

#### Create Service Account

To create the ReportPortal Service Account and ClusterRoleBinding:

```bash
export SERVICE_ACCOUNT_NAME="${APP_INSTANCE_NAME}-serviceaccount"

kubectl create serviceaccount "${SERVICE_ACCOUNT_NAME}" --namespace "${NAMESPACE}"
kubectl create clusterrole "${SERVICE_ACCOUNT_NAME}-role" --verb=get,list,watch --resource=pods,services,jobs --namespace "${NAMESPACE}"
kubectl create clusterrolebinding "${SERVICE_ACCOUNT_NAME}-rule" --clusterrole="${SERVICE_ACCOUNT_NAME}-role" --serviceaccount="${NAMESPACE}:${SERVICE_ACCOUNT_NAME}"
```

#### Expanding the manifest template

```bash
helm template chart/reportportal-k8s-app \
    --name ${APP_INSTANCE_NAME} \
    --namespace ${NAMESPACE} \
    --set reportportal.serviceapi.image.repository=${IMAGE_REPO_API} \
    --set reportportal.serviceapi.image.tag=${TAG} \
    --set reportportal.serviceindex.image.repository=${IMAGE_REPO_INDEX} \
    --set reportportal.serviceindex.image.tag=${TAG} \
    --set reportportal.serviceui.image.repository=${IMAGE_REPO_UI} \
    --set reportportal.serviceui.image.tag=${TAG} \
    --set reportportal.uat.image.repository=${IMAGE_REPO_UAT} \
    --set reportportal.uat.image.tag=${TAG} \
    --set reportportal.servicejobs.image.repository=${IMAGE_REPO_JOBS} \
    --set reportportal.servicejobs.image.tag=${TAG} \
    --set reportportal.serviceanalyzer.image.repository=${IMAGE_REPO_ANALYZER} \
    --set reportportal.serviceanalyzer.image.tag=${TAG} \
    --set reportportal.servicemetricsgatherer.image.repository=${IMAGE_REPO_METRICGATHERER} \
    --set reportportal.servicemetricsgatherer.image.tag=${TAG} \
    --set reportportal.migrations.image.repository=${IMAGE_REPO_MIGRATOR} \
    --set reportportal.migrations.image.tag=${TAG} \
    --set reportportal.postgresql.image.registry=${IMAGE_REGISTRY_DB} \
    --set reportportal.postgresql.image.repository=${IMAGE_REPO_DB} \
    --set reportportal.postgresql.image.tag=${TAG} \
    --set reportportal.rabbitmq.image.registry=${IMAGE_REGISTRY_RABBITMQ} \
    --set reportportal.rabbitmq.image.repository=${IMAGE_REPO_RABBITMQ} \
    --set reportportal.rabbitmq.image.tag=${TAG} \
    --set reportportal.opensearch.image.repository=${IMAGE_REPO_OS} \
    --set reportportal.opensearch.image.tag=${TAG} \
    --set reportportal.minio.image.registry=${IMAGE_REGISTRY_BLOB} \
    --set reportportal.minio.image.repository=${IMAGE_REPO_BLOB} \
    --set reportportal.minio.image.tag=${TAG} \
    --set reportportal.k8sWaitFor.image.repository=${IMAGE_REPO_INIT} \
    --set reportportal.k8sWaitFor.image.tag=${TAG} \
    --set reportportal.uat.superadminInitPasswd.password=${SUPERADMIN_PASSWORD} \
    --set reportportal.serviceAccount.name=${SERVICE_ACCOUNT_NAME} \
    --set reportportal.ingress.tls.secret.base64EncodedPrivateKey=${TLS_CERTIFICATE_KEY} \
    --set reportportal.ingress.tls.secret.base64EncodedCertificate=${TLS_CERTIFICATE_CRT} \
    > "${APP_INSTANCE_NAME}_manifest.yaml"
```

#### Applying the manifest to your Kubernetes cluster

To apply the manifest to your Kubernetes cluster, use kubectl:

```bash
kubectl apply -f "${APP_INSTANCE_NAME}_manifest.yaml" --namespace "${NAMESPACE}"
```

#### Viewing your app in the Google Cloud Console

To get the Cloud Console URL for your app, run the following command:

```bash
echo "https://console.cloud.google.com/kubernetes/application/${ZONE}/${CLUSTER}/${NAMESPACE}/${APP_INSTANCE_NAME}"
```

To view the app, open the URL in your browser.

#### Open ReportPortal UI in your browser

```bash
SERVICE_IP=$(kubectl get ingress \
--namespace {{ .Release.Namespace }} \
--output jsonpath='{$.items[0].status.loadBalancer.ingress[0].ip}') \
&& echo "https://${SERVICE_IP}/"
```

Use superadmin as a login and the password you set in the environment variable SUPERADMIN_PASSWORD.
