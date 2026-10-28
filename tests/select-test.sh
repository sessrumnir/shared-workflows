#!/usr/bin/env bash
# Runs the "Select what this run needs" step of collection-ci.yml against a scratch repository and
# checks the mode and scenarios it picks for each kind of change.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

python3 - "${root}/.github/workflows/collection-ci.yml" > "${work}/select.sh" <<'EOF'
import sys
import yaml
steps = yaml.safe_load(open(sys.argv[1]))["jobs"]["changes"]["steps"]
print(next(step["run"] for step in steps if step.get("id") == "select"))
EOF

repo=${work}/repo
git init -q -b main "${repo}"
for scenario in default frr kea_dhcp kea_dhcp_container; do
  mkdir -p "${repo}/extensions/molecule/${scenario}"
  echo --- > "${repo}/extensions/molecule/${scenario}/molecule.yml"
done
git -C "${repo}" add -A
git -C "${repo}" -c user.name=t -c user.email=t@example.com commit -q -m base
base=$(git -C "${repo}" rev-parse HEAD)
scenarios='["default","frr","kea_dhcp","kea_dhcp_container"]'
failures=0

check() {
  local name=$1 expected=$2 mode=$3 draft=$4 ref=$5
  shift 5
  git -C "${repo}" checkout -q -B change "${base}"
  for file in "$@"; do
    mkdir -p "${repo}/$(dirname "${file}")"
    echo change >> "${repo}/${file}"
  done
  if [ "$#" -gt 0 ]; then
    git -C "${repo}" add -A
    git -C "${repo}" -c user.name=t -c user.email=t@example.com commit -q -m change
  fi
  local got pr_base=${base} pr_head
  pr_head=$(git -C "${repo}" rev-parse HEAD)
  if [ "${ref}" = push ]; then
    pr_base='' pr_head=''
  fi
  got=$(cd "${repo}" && MODE=${mode} DRAFT=${draft} HEAD_REF=${ref} BASE=${pr_base} \
    HEAD=${pr_head} SCENARIOS=${scenarios} GITHUB_OUTPUT=/dev/null \
    bash "${work}/select.sh" 2>&1 | tail -n 1) || true
  if [ "${got}" = "${expected}" ]; then
    echo "ok    ${name}"
  else
    echo "FAIL  ${name}: expected '${expected}', got '${got}'"
    failures=$((failures + 1))
  fi
}

all="mode: full, scenarios: ${scenarios}"
check "merge to main" "mode: fast, scenarios: []" fast "" "" roles/frr/tasks/main.yml
check "nightly" "${all}" full "" ""
check "draft" "mode: skip, scenarios: []" auto true feat/x roles/frr/tasks/main.yml
check "release pull request" "mode: lint, scenarios: []" auto false release-please--branches--main galaxy.yml
check "docs only" "mode: lint, scenarios: []" auto false feat/x README.md docs/x.md roles/frr/README.md
check "hook bump" "mode: lint, scenarios: []" auto false feat/x .pre-commit-config.yaml
check "one role" 'mode: full, scenarios: ["default","frr"]' auto false feat/x roles/frr/tasks/main.yml
check "role with variants" 'mode: full, scenarios: ["default","kea_dhcp","kea_dhcp_container"]' auto false feat/x roles/kea_dhcp/defaults/main.yml
check "two roles" 'mode: full, scenarios: ["default","frr","kea_dhcp","kea_dhcp_container"]' auto false feat/x roles/frr/a roles/kea_dhcp/a
check "one scenario directory" 'mode: full, scenarios: ["frr"]' auto false feat/x extensions/molecule/frr/verify.yml
check "shared Molecule files" "${all}" auto false feat/x extensions/molecule/shared/x.yml
check "plugin" "${all}" auto false feat/x plugins/filter/x.py
check "role and plugin" "${all}" auto false feat/x roles/frr/a plugins/filter/x.py
check "role without a scenario" 'mode: full, scenarios: ["default"]' auto false feat/x roles/pki/tasks/main.yml
check "auto without pull request SHAs" "${all}" auto false push roles/frr/tasks/main.yml
listed=${scenarios}
scenarios='["default","nope"]'
check "a listed scenario that does not exist" "::error::molecule-scenarios names nope, which has no extensions/molecule/nope/molecule.yml" full "" ""
scenarios='["default","default"]'
check "a list with a duplicate" "::error::molecule-scenarios must be a JSON list of up to 50 distinct scenario names" full "" ""
scenarios='["../x"]'
check "a list with a path" "::error::molecule-scenarios must be a JSON list of up to 50 distinct scenario names" full "" ""
scenarios=${listed}

# Without a list, every scenario that runs on the shared Docker driver.
git -C "${repo}" checkout -q -B discover "${base}"
rm -r "${repo}/extensions/molecule/kea_dhcp" "${repo}/extensions/molecule/kea_dhcp_container"
for scenario in default frr vm; do
  mkdir -p "${repo}/extensions/molecule/${scenario}"
  echo --- > "${repo}/extensions/molecule/${scenario}/molecule.yml"
done
printf 'driver:\n  name: vagrant\n' >> "${repo}/extensions/molecule/vm/molecule.yml"
mkdir -p "${repo}/extensions/molecule/shared"
echo --- > "${repo}/extensions/molecule/shared/x.yml"
git -C "${repo}" add -A
git -C "${repo}" -c user.name=t -c user.email=t@example.com commit -q -m scenarios
base=$(git -C "${repo}" rev-parse HEAD)
scenarios=''
all='mode: full, scenarios: ["default","frr"]'
check "discovered scenarios" "${all}" full "" ""
check "discovered, one role" 'mode: full, scenarios: ["default","frr"]' auto false feat/x roles/frr/tasks/main.yml
check "discovered, a VM scenario directory" "${all}" auto false feat/x extensions/molecule/vm/converge.yml

[ "${failures}" -eq 0 ] || { echo "${failures} case(s) failed"; exit 1; }
