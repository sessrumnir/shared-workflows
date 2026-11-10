#!/usr/bin/env bash
# Signs DIGEST keyless with the workflow's GitHub identity and attaches IMAGE/sbom.spdx.json as a
# signed SPDX attestation. cosign runs on the Docker daemon, which sees only the work directory, as
# the runner's user so it can read the registry login in CONFIG, which is removed afterwards.
set -euo pipefail

trap 'rm -rf "${CONFIG}"' EXIT
signer=(docker run --rm --read-only --tmpfs /tmp --user "$(id -u):$(id -g)"
  --cap-drop ALL --security-opt no-new-privileges
  --env HOME=/tmp --env DOCKER_CONFIG=/docker
  --env ACTIONS_ID_TOKEN_REQUEST_URL --env ACTIONS_ID_TOKEN_REQUEST_TOKEN
  --volume "${CONFIG}:/docker:ro" --volume "${IMAGE}:/image:ro" "${COSIGN}")
"${signer[@]}" sign --yes "${DIGEST}"
"${signer[@]}" attest --yes --type spdxjson --predicate /image/sbom.spdx.json "${DIGEST}"
echo "::notice::signed ${DIGEST}"
