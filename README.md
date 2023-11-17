# gcp-k8s-app

ReportPortal Kubrentes repository wrapper for Google Cloud Platform Marketplace

## Commands for the Deployer image

Configures Docker to use gcloud as a credential helper for gcr.io:

```bash
make configure
```

Build deployer docker image:

```bash
make tag=${sematic version}
```

Push deployer docker image to Artifact Registry:

```bash
make tag=${sematic version} push
```
