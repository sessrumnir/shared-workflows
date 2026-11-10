#!/usr/bin/env bash
# Pushes the tested image in IMAGE to REF as stable, <version>-<UTC time> and <version>, the version
# test.sh printed. A digest in IMAGE/digest (CI_IMAGE@sha256:…) is copied with crane, unchanged, so
# GHCR serves the very digest test pulled; else IMAGE/image.tar is loaded and pushed. Prints the
# pushed REF@sha256:… as the output digest.
set -euo pipefail

version=$(cat "${IMAGE}/version")
if [ -n "${version}" ] && ! [[ ${version} =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
  echo "::error::version ${version}, expected digits and dots"
  exit 1
fi
tags=(stable "${version:+${version}-}$(date -u +%Y%m%d%H%M%S)")
if [ -n "${version}" ]; then
  tags+=("${version}")
fi
export DOCKER_CONFIG=${CONFIG}
printf '%s' "${TOKEN}" | docker login ghcr.io --username "${ACTOR}" --password-stdin

if [ -f "${IMAGE}/digest" ]; then
  source=$(cat "${IMAGE}/digest")
  if ! [[ ${source} =~ ^"${CI_IMAGE}"@(sha256:[0-9a-f]{64})$ ]]; then
    echo "::error::unexpected CI registry digest ${source}"
    exit 1
  fi
  digest=${REF}@${BASH_REMATCH[1]}
  copier=(docker run --rm --read-only --tmpfs /tmp --user "$(id -u):$(id -g)"
    --cap-drop ALL --security-opt no-new-privileges
    --env HOME=/tmp --env DOCKER_CONFIG=/docker --env SSL_CERT_DIR=/etc/ssl/certs:/etc/ci-registry-ca
    --volume "${DOCKER_CONFIG}:/docker:ro" --volume /etc/ci-registry-ca:/etc/ci-registry-ca:ro "${CRANE}")
  "${copier[@]}" copy "${source}" "${REF}:${tags[0]}"
  for tag in "${tags[@]:1}"; do
    "${copier[@]}" tag "${digest}" "${tag}"
  done
else
  docker load --input "${IMAGE}/image.tar"
  for tag in "${tags[@]}"; do
    docker tag "${REF}:stable" "${REF}:${tag}"
    docker push "${REF}:${tag}"
  done
  digest=$(docker image inspect --format '{{index .RepoDigests 0}}' "${REF}:stable")
fi
if ! [[ ${digest} =~ ^"${REF}"@sha256:[0-9a-f]{64}$ ]]; then
  echo "::error::unexpected digest reference ${digest}"
  exit 1
fi
echo "::notice::${REF}: ${tags[*]}"
echo "digest=${digest}" >> "${GITHUB_OUTPUT}"
