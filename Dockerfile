# FROM marketplace.gcr.io/google/c2d-debian11 AS build

# RUN apt-get update && apt-get install -y --no-install-recommends \
#     python3 \
#     python3-pip \
#     python3-setuptools \
#     && pip install --upgrade pip \
#     && pip install --upgrade wheel \
#     && pip install cqlsh futures \
#     && rm -rf /var/lib/apt/lists/*

# RUN app_version=$TAG python scripts/build-app-spec.py

FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild

ENV WAIT_FOR_READY_TIMEOUT 1800
ENV TESTER_TIMEOUT 1800