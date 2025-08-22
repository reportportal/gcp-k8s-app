# Repository Guidelines

## Project Structure & Module Organization
- `data/`: Deployer Dockerfile, Marketplace `schema.yaml`, and Helm chart under `data/chart/reportportal-k8s-app` (`Chart.yaml`, `values.yaml`, `templates/`).
- `scripts/`: Utility scripts (e.g., `publish-gcr.py` for retagging/publishing images).
- `tester/`: Marketplace testrunner config (`tests/basic-suite.yaml`) and `tester.sh` wrapper.
- `docs/`: Operational guides (build chart, release flow).
- Root: `Makefile` (primary entrypoint), `README.md`, `.env` (local examples).

## Build, Test, and Development Commands
- `make info`: Prints release track, app/dep versions, image names.
- `make deploy`: Builds and pushes the deployer image (uses Helm deps).
- `make deploy-deps`: Pulls chart images and republishes them to GCR/AR.
- `make deploy-all`: Runs `deploy` + `deploy-deps`.
- `make test-cluster` + `make test-cluster-setup`: Creates GKE cluster and installs CRDs/namespace.
- `make test-install`: Installs via `mpdev install` with minimal params.
- `make verify`: Runs Marketplace verification (`testrunner`).
- `make clean`: Deletes test cluster and disks.
Prereqs: `gcloud`, `kubectl`, `helm`, `mpdev`, `yq`, `docker`, `crane` (see `docs/`). Example: `gcloud auth configure-docker gcr.io`.

## Coding Style & Naming Conventions
- YAML/Helm: 2-space indent; keep keys lowercase; follow existing value keys (e.g., `reportportal.serviceui.image.*`).
- Python (`scripts/`): PEP 8, 4-space indents, `snake_case`, check `subprocess` return codes; avoid logging secrets.
- Bash: `set -euo pipefail`; quote variables; prefer long flags.
- Filenames: hyphen-case for docs/scripts; retain chart name `reportportal-k8s-app`.

## Testing Guidelines
- Tests live in `tester/tests` as testrunner specs (`*-suite.yaml`).
- Add simple bash tests (e.g., `curl` endpoint) and keep them idempotent.
- Run via `make verify` after a successful `make test-install`.

## Commit & Pull Request Guidelines
- Use Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:` (see git history).
- PRs must include: purpose, key changes, test plan (`make verify` output), and any Marketplace/Chart version bumps.
- Link issues; attach logs/screenshots when relevant (e.g., Console app view).

## Security & Configuration Tips
- Do not commit real secrets; `.env` is example-only.
- In `data/schema.yaml`, keep `publishedVersion` aligned with deployer tag; validate with `make info`.
- Review `Makefile` vars (`gcp_project`, `rpp_service_name`) before publishing.
