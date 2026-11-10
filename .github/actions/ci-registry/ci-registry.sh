#!/usr/bin/env bash
# Writes the CI registry robot that the runner mounts in ROBOT (username, password) into the Docker
# config in CONFIG, beside any login already there, and prints the run's CI image repository.
set -euo pipefail

robot=${ROBOT:-/etc/ci-registry}
if ! [[ ${REGISTRY} =~ ^[A-Za-z0-9.-]+(:[0-9]+)?$ ]]; then
  echo "::error::CI_REGISTRY must be a host with an optional port, not ${REGISTRY}"
  exit 1
fi
ci_image="${REGISTRY}/${GITHUB_REPOSITORY_OWNER}-ci/${GITHUB_REPOSITORY#*/}/${IMAGE}"
echo "image=${ci_image}" >> "${GITHUB_OUTPUT}"

if ! [ -s "${robot}/username" ] || ! [ -s "${robot}/password" ]; then
  if [ "${REQUIRED}" = true ]; then
    echo "::error::CI_REGISTRY is set, but this runner has no CI registry robot in ${robot}"
    exit 1
  fi
  echo "::notice::no CI registry robot on this runner; building without the registry cache"
  echo "ready=false" >> "${GITHUB_OUTPUT}"
  exit 0
fi

username=$(tr -d '\n' < "${robot}/username")
password=$(tr -d '\n' < "${robot}/password")
echo "::add-mask::${password}"
auth=$(printf '%s:%s' "${username}" "${password}" | base64 -w0)
echo "::add-mask::${auth}"
mkdir -p "${CONFIG}"
file=${CONFIG}/config.json
if ! [ -s "${file}" ]; then
  echo '{}' > "${file}"
fi
jq --arg host "${REGISTRY}" --arg auth "${auth}" '.auths[$host].auth = $auth' "${file}" > "${file}.new"
chmod 600 "${file}.new"
mv "${file}.new" "${file}"
echo "ready=true" >> "${GITHUB_OUTPUT}"
