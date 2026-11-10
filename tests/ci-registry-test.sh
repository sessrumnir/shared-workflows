#!/usr/bin/env bash
# Runs the ci-registry action's script against scratch robot files and checks the Docker config and
# outputs it writes.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

script=${root}/.github/actions/ci-registry/ci-registry.sh
failures=0

run() {
  local registry=$1 required=$2
  : > "${work}/output"
  ROBOT=${work}/robot CONFIG=${work}/docker REGISTRY=${registry} IMAGE=crane REQUIRED=${required} \
    GITHUB_REPOSITORY_OWNER=sessrumnir GITHUB_REPOSITORY=sessrumnir/images GITHUB_OUTPUT=${work}/output \
    bash "${script}" 2>&1 | grep -v '^::add-mask::' | tail -n 1 || true
}

check() {
  local name=$1 expected=$2 got=$3
  if [ "${got}" = "${expected}" ]; then
    echo "ok    ${name}"
  else
    echo "FAIL  ${name}: expected '${expected}', got '${got}'"
    failures=$((failures + 1))
  fi
}

reset() {
  rm -rf "${work}/robot" "${work}/docker"
  mkdir -p "${work}/robot"
  printf "robot\$ci\n" > "${work}/robot/username"
  printf 's3cret' > "${work}/robot/password"
}

reset
run registry.test:8443 true > /dev/null
check "writes the login" "$(printf "robot\$ci:s3cret" | base64 -w0)" \
  "$(jq -r '.auths["registry.test:8443"].auth' "${work}/docker/config.json")"
check "outputs ready and the image" \
  "image=registry.test:8443/sessrumnir-ci/images/crane ready=true" "$(paste -sd ' ' "${work}/output")"
check "keeps the config private" 600 "$(stat -c %a "${work}/docker/config.json")"

reset
mkdir -p "${work}/docker"
echo '{"auths": {"ghcr.io": {"auth": "x"}}}' > "${work}/docker/config.json"
run registry.test true > /dev/null
check "keeps other logins" "ghcr.io registry.test" \
  "$(jq -r '.auths | keys | join(" ")' "${work}/docker/config.json")"

reset
rm "${work}/robot/password"
check "no robot, required" "::error::CI_REGISTRY is set, but this runner has no CI registry robot in ${work}/robot" \
  "$(run registry.test true)"

reset
rm -rf "${work}/robot"
check "no robot, optional" "::notice::no CI registry robot on this runner; building without the registry cache" \
  "$(run registry.test false)"
check "outputs not ready" "image=registry.test/sessrumnir-ci/images/crane ready=false" "$(paste -sd ' ' "${work}/output")"

reset
check "refuses a URL" "::error::CI_REGISTRY must be a host with an optional port, not https://registry.test" \
  "$(run https://registry.test true)"
check "writes nothing for a URL" absent "$( [ -e "${work}/docker" ] && echo present || echo absent)"

[ "${failures}" -eq 0 ] || { echo "${failures} case(s) failed"; exit 1; }
