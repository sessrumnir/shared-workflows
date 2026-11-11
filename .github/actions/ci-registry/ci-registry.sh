#!/usr/bin/env bash
# Writes the CI registry robot that the runner mounts in ROBOT (registry, username, password) into
# the Docker config in CONFIG, beside any login already there, and prints the run's CI image
# repository. The registry host comes only from the runner and is masked before anything prints it.
set -euo pipefail

robot=${ROBOT:-/etc/ci-registry}
for key in registry username password; do
  if ! [ -s "${robot}/${key}" ]; then
    if [ "${REQUIRED}" = true ]; then
      echo "::error::CI_REGISTRY is on, but this runner has no CI registry robot in ${robot}"
      exit 1
    fi
    echo "::notice::no CI registry robot on this runner; building without the registry cache"
    echo "ready=false" >> "${GITHUB_OUTPUT}"
    exit 0
  fi
done

registry=$(tr -d '\n' < "${robot}/registry")
echo "::add-mask::${registry}"
if ! [[ ${registry} =~ ^[A-Za-z0-9.-]+(:[0-9]+)?$ ]]; then
  echo "::error::the robot's registry in ${robot} must be a host with an optional port"
  exit 1
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
jq --arg host "${registry}" --arg auth "${auth}" '.auths[$host].auth = $auth' "${file}" > "${file}.new"
chmod 600 "${file}.new"
mv "${file}.new" "${file}"
echo "image=${registry}/${GITHUB_REPOSITORY_OWNER}-ci/${GITHUB_REPOSITORY#*/}/${IMAGE}" >> "${GITHUB_OUTPUT}"
echo "ready=true" >> "${GITHUB_OUTPUT}"
