#!/usr/bin/env bash
# Runs the ci-registry action's script against scratch robot files and checks the Docker config and
# outputs it writes, and that the registry host is masked before anything prints it.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

script=${root}/.github/actions/ci-registry/ci-registry.sh
failures=0

run() {
  local required=$1
  : > "${work}/output"
  ROBOT=${work}/robot CONFIG=${work}/docker IMAGE=crane REQUIRED=${required} \
    GITHUB_REPOSITORY_OWNER=sessrumnir GITHUB_REPOSITORY=sessrumnir/images GITHUB_OUTPUT=${work}/output \
    bash "${script}" > "${work}/log" 2>&1 || true
  grep -v '^::add-mask::' "${work}/log" | tail -n 1 || true
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
  printf '%s\n' "${1:-registry.test:8443}" > "${work}/robot/registry"
  printf "robot\$ci\n" > "${work}/robot/username"
  printf 's3cret' > "${work}/robot/password"
}

reset
run true > /dev/null
check "writes the login" "$(printf "robot\$ci:s3cret" | base64 -w0)" \
  "$(jq -r '.auths["registry.test:8443"].auth' "${work}/docker/config.json")"
check "outputs ready and the image" \
  "image=registry.test:8443/sessrumnir-ci/images/crane ready=true" "$(paste -sd ' ' "${work}/output")"
check "keeps the config private" 600 "$(stat -c %a "${work}/docker/config.json")"
check "masks the host first" "::add-mask::registry.test:8443" "$(head -n 1 "${work}/log")"

reset registry.test
mkdir -p "${work}/docker"
echo '{"auths": {"ghcr.io": {"auth": "x"}}}' > "${work}/docker/config.json"
run true > /dev/null
check "keeps other logins" "ghcr.io registry.test" \
  "$(jq -r '.auths | keys | join(" ")' "${work}/docker/config.json")"

for key in registry password; do
  reset
  rm "${work}/robot/${key}"
  check "no ${key}, required" "::error::CI_REGISTRY is on, but this runner has no CI registry robot in ${work}/robot" \
    "$(run true)"
done

reset
rm -rf "${work}/robot"
check "no robot, optional" "::notice::no CI registry robot on this runner; building without the registry cache" \
  "$(run false)"
check "outputs not ready" "ready=false" "$(paste -sd ' ' "${work}/output")"

reset https://registry.test
check "refuses a URL" "::error::the robot's registry in ${work}/robot must be a host with an optional port" \
  "$(run true)"
check "masks the URL first" "::add-mask::https://registry.test" "$(head -n 1 "${work}/log")"
check "writes nothing for a URL" absent "$( [ -e "${work}/docker" ] && echo present || echo absent)"

[ "${failures}" -eq 0 ] || { echo "${failures} case(s) failed"; exit 1; }
