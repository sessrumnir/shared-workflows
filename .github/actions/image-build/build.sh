#!/usr/bin/env bash
# Builds the image in DIRECTORY on the runner's rootless BuildKit (BUILDKIT_HOST, client key in
# ~/.buildkit). registry: pushes it to CI_IMAGE:run-<run>-<attempt> and keeps main's layer cache in
# CI_IMAGE:buildcache. cache: writes OUTPUT/image.tar, tagged REF:stable.
set -euo pipefail

export DOCKER_CONFIG=${CONFIG}
trap 'rm -rf "${DOCKER_CONFIG}"' EXIT
server=${BUILDKIT_HOST#tcp://}
server=${server%:*}
docker buildx create --name ci --use --driver remote \
  --driver-opt "cacert=${HOME}/.buildkit/ca.crt,cert=${HOME}/.buildkit/tls.crt,key=${HOME}/.buildkit/tls.key,servername=${server}" \
  "${BUILDKIT_HOST}"

layers=${CI_IMAGE}:buildcache
if [ "${HANDOFF}" = registry ]; then
  docker buildx build --pull --file "${DIRECTORY}/Containerfile" \
    --cache-from "type=registry,ref=${layers}" \
    --cache-to "type=registry,ref=${layers},mode=max,image-manifest=true,oci-mediatypes=true" \
    --output "type=image,name=${CI_IMAGE}:run-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT},push=true" "${DIRECTORY}"
  exit 0
fi

options=()
if [ "${FRESH}" = true ]; then
  options=(--no-cache --pull)
elif [ "${CACHE}" = true ]; then
  options=(--cache-from "type=registry,ref=${layers}")
fi
mkdir -p "${OUTPUT}"
docker buildx build "${options[@]}" --file "${DIRECTORY}/Containerfile" \
  --output "type=docker,dest=${OUTPUT}/image.tar" --tag "${REF}:stable" "${DIRECTORY}"
