#!/usr/bin/env bash
# Lints DIRECTORY/Containerfile with hadolint, runs DIRECTORY/test.sh on REF:stable, scans TARBALL
# with trivy for fixable HIGH and CRITICAL findings, and writes the version test.sh printed
# (version=<x>) and an SPDX SBOM to OUTPUT. The GHCR login lives in a throwaway Docker config that
# is gone before any repository code runs.
set -euo pipefail

login=$(mktemp -d)
trap 'rm -rf "${login}"' EXIT
printf '%s' "${TOKEN}" | docker --config "${login}" login ghcr.io --username "${ACTOR}" --password-stdin
docker --config "${login}" pull --quiet "${HADOLINT}"
rm -rf "${login}"
docker run --rm --interactive --volume "${PWD}/.hadolint.yaml:/hadolint.yaml:ro" \
  "${HADOLINT}" --config /hadolint.yaml - < "${DIRECTORY}/Containerfile"

"${DIRECTORY}/test.sh" "${REF}:stable" | tee "${RUNNER_TEMP}/test.log"
version=$(sed -n 's/^version=//p' "${RUNNER_TEMP}/test.log" | tail -n 1)
if [ -n "${version}" ] && ! [[ ${version} =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
  echo "::error::test.sh printed version=${version}, expected digits and dots"
  exit 1
fi
mkdir -p "${OUTPUT}"
printf '%s' "${version}" > "${OUTPUT}/version"

mkdir -p "${RUNNER_TEMP}/trivy"
trivy() {
  docker run --rm --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges \
    --user "$(id -u):$(id -g)" --env HOME=/tmp --workdir /src \
    --volume "${PWD}:/src:ro" --volume "${RUNNER_TEMP}/trivy:/cache" \
    --volume "${TARBALL}:/image.tar:ro" \
    "${TRIVY}" image --cache-dir /cache --input /image.tar "$@"
}
trivy --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --no-progress
trivy --format spdx-json --quiet > "${OUTPUT}/sbom.spdx.json"
