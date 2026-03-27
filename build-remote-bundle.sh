#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${OUT_DIR:-${SCRIPT_DIR}/out}"
NODE_VERSION="${NODE_VERSION:-24.13.1}"
IMAGE_TAG="${IMAGE_TAG:-t3code-remote-bundle:local}"
HOST_ARCH="$(uname -m)"

mkdir -p "${OUT_DIR}"

if docker buildx version >/dev/null 2>&1; then
	docker buildx build \
		--platform linux/amd64 \
		--build-arg "NODE_VERSION=${NODE_VERSION}" \
		--file "${SCRIPT_DIR}/Dockerfile" \
		--output "type=local,dest=${OUT_DIR}" \
		"${REPO_ROOT}"
else
	if [[ "${HOST_ARCH}" != "x86_64" && "${HOST_ARCH}" != "amd64" ]]; then
		printf 'error: docker buildx is required to build a linux/amd64 bundle from host arch %s\n' "${HOST_ARCH}" >&2
		printf 'hint: install/enable the Docker buildx plugin on your machine and rerun this script\n' >&2
		exit 1
	fi

	docker build \
		--build-arg "NODE_VERSION=${NODE_VERSION}" \
		--file "${SCRIPT_DIR}/Dockerfile" \
		--target export \
		--tag "${IMAGE_TAG}" \
		"${REPO_ROOT}"

	container_id="$(docker create "${IMAGE_TAG}")"
	cleanup() {
		docker rm -f "${container_id}" >/dev/null 2>&1 || true
	}
	trap cleanup EXIT

	docker cp "${container_id}:/t3code-remote-linux-x64.tar.gz" \
		"${OUT_DIR}/t3code-remote-linux-x64.tar.gz"

	cleanup
	trap - EXIT
fi

printf 'Remote bundle written to %s/t3code-remote-linux-x64.tar.gz\n' "${OUT_DIR}"
