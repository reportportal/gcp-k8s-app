# Build a custom Helm chart

## Prerequisites

For this guide, you need the following:

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) - Kubernetes command-line tool
- [helm](https://helm.sh/docs/intro/install/) - Helm command-line tool
- [gcloud](https://cloud.google.com/sdk/gcloud/) - Google Cloud SDK
- [gcloud gke auth plugin](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_plugin) - Google Cloud SDK Kubernetes Engine plugin
- [mpdev](https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/master/docs/mpdev-references.md#overview-and-setup) - Google Cloud Marketplace development tool
- [yq](https://github.com/mikefarah/yq/?tab=readme-ov-file#install) - YAML processor for parsing Chart.yaml

## Builds a chart

Download ReportPortal Helm chart and unpack it to the chart directory:

```bash
helm pull reportportal/reportportal --untar --untardir tmp/chart
```

Change the chart values or dependencies in the chart directory.

Create a new Helm chart package:

```bash
helm package tmp/chart/reportportal
```

Set local environment variables:

```bash
export PROJECT_ID=$(gcloud config get-value project | tr ':' '/')
export REPO_LOCATION=us
export REPO_NAME=reportportal
export VERSION=24.1.4
```

Get credentials for the Google Container Registry:

```bash
gcloud auth print-access-token | helm registry login -u oauth2accesstoken --password-stdin https://$REPO_LOCATION-docker.pkg.dev
```

Push the Helm chart to the Google Container Registry:

```bash
helm push reportportal-$VERSION.tgz oci://$REPO_LOCATION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME
```

Update a version and dependencies in the Chart.yaml in the data directory:
  
```yaml
version: &version 24.1.4
dependencies:
- name: reportportal
  version: *version
  repository: oci://us-docker.pkg.dev/epam-mp-rp/reportportal
```

After it you can install and test custom ReportPortal Helm chart:

```bash
make test-install
```

or verify via Google mpdev tool:

```bash
make verify
```
