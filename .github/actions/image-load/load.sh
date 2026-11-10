#!/usr/bin/env bash
# Puts the built image into the runner's Docker as REF:stable. cache: loads OUTPUT/image.tar.
# registry: pulls CI_IMAGE:run-<run>-<attempt> from the latest attempt that built it (a rerun of a
# failed test reuses the build), records its digest in OUTPUT/digest for push, and saves a tarball
# to scan in RUNNER_TEMP. Prints the tarball's path as the output tarball.
set -euo pipefail

mkdir -p "${OUTPUT}"
if [ "${HANDOFF}" = cache ]; then
  docker load --input "${OUTPUT}/image.tar"
  echo "tarball=${OUTPUT}/image.tar" >> "${GITHUB_OUTPUT}"
  exit 0
fi

trap 'rm -rf "${CONFIG}"' EXIT
image=''
for attempt in $(seq "${GITHUB_RUN_ATTEMPT}" -1 1); do
  if docker --config "${CONFIG}" pull --quiet "${CI_IMAGE}:run-${GITHUB_RUN_ID}-${attempt}"; then
    image=${CI_IMAGE}:run-${GITHUB_RUN_ID}-${attempt}
    break
  fi
done
if [ -z "${image}" ]; then
  echo "::error::no ${CI_IMAGE}:run-${GITHUB_RUN_ID}-<attempt> in the CI registry"
  exit 1
fi
digest=$(docker image inspect --format '{{json .RepoDigests}}' "${image}" \
  | jq -r --arg repo "${CI_IMAGE}" '.[] | select(startswith($repo + "@"))')
if ! [[ ${digest} =~ ^"${CI_IMAGE}"@sha256:[0-9a-f]{64}$ ]]; then
  echo "::error::unexpected digest reference ${digest}"
  exit 1
fi
docker tag "${image}" "${REF}:stable"
printf '%s' "${digest}" > "${OUTPUT}/digest"
tarball=${RUNNER_TEMP}/scan/image.tar
mkdir -p "${tarball%/*}"
docker save --output "${tarball}" "${REF}:stable"
echo "tarball=${tarball}" >> "${GITHUB_OUTPUT}"
