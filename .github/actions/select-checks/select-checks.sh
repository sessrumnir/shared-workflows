#!/usr/bin/env bash
# Writes mode=<skip|lint|fast|full> and scenarios=<JSON list> to GITHUB_OUTPUT for collection-ci.
set -euo pipefail

if [ -n "${SCENARIOS}" ]; then
  all=$(jq -c . <<< "${SCENARIOS}")
  if ! jq -e 'type == "array" and length <= 50 and all(.[]; type == "string" and test("^[a-z0-9_-]+$")) and length == (unique | length)' <<< "${all}" > /dev/null; then
    echo "::error::molecule-scenarios must be a JSON list of up to 50 distinct scenario names"
    exit 1
  fi
  for scenario in $(jq -r '.[]' <<< "${all}"); do
    if [ ! -f "extensions/molecule/${scenario}/molecule.yml" ]; then
      echo "::error::molecule-scenarios names ${scenario}, which has no extensions/molecule/${scenario}/molecule.yml"
      exit 1
    fi
  done
else
  all=$(for file in extensions/molecule/*/molecule.yml; do
          if [ -f "${file}" ] && ! grep -q '^driver:' "${file}"; then
            basename "$(dirname "${file}")"
          fi
        done | jq -Rcs 'split("\n") | map(select(length > 0))')
fi

# Writes the decision as job outputs: a mode and a JSON list of scenarios.
emit() {
  echo "mode=$1" >> "${GITHUB_OUTPUT}"
  echo "scenarios=$2" >> "${GITHUB_OUTPUT}"
  echo "mode: $1, scenarios: $2"
}

# Files that need lint and nothing else.
lint_only() {
  [[ $1 =~ (\.md$|^docs/|^license$|^LICENSE$|^\.markdownlint|^\.pre-commit-config\.yaml$|^(\.github/)?renovate\.json$|^\.gitignore$|^\.gitleaks\.toml$) ]]
}

# The scenarios a role change needs: default, the role's own and its variants (kea_dhcp_*).
scenarios_for_role() {
  jq -c --arg role "$1" '[.[] | select(. == "default" or . == $role or startswith($role + "_"))]' <<< "${all}"
}

# A pull request: lint alone for lint-only files; otherwise the scenarios of the touched
# roles or scenario directories, and every scenario for anything else.
select_from_diff() {
  local needs=lint selected='[]' file
  while IFS= read -r file; do
    if [ -z "${file}" ] || lint_only "${file}"; then
      continue
    fi
    needs=full
    if [[ ${file} =~ ^roles/([^/]+)/ ]]; then
      selected=$(jq -c --argjson add "$(scenarios_for_role "${BASH_REMATCH[1]}")" '. + $add' <<< "${selected}")
    elif [[ ${file} =~ ^extensions/molecule/([^/]+)/ ]] && jq -e --arg s "${BASH_REMATCH[1]}" 'index($s)' <<< "${all}" > /dev/null; then
      selected=$(jq -c --arg s "${BASH_REMATCH[1]}" '. + [$s]' <<< "${selected}")
    else
      selected=${all}
      break
    fi
  done < <(git diff --name-only "${BASE}...${HEAD}")
  if [ "${needs}" = lint ]; then
    emit lint '[]'
  elif [ "${selected}" = '[]' ]; then
    emit full "${all}"
  else
    emit full "$(jq -c --argjson all "${all}" '$all - ($all - .)' <<< "${selected}")"
  fi
}

case "${MODE}" in
  fast) emit fast '[]' ;;
  full) emit full "${all}" ;;
  auto)
    if [ "${DRAFT}" = true ]; then
      emit skip '[]'
    elif [ -z "${BASE}" ] || [ -z "${HEAD}" ]; then
      emit full "${all}"
    elif [[ ${HEAD_REF} == release-please--* ]]; then
      emit lint '[]'
    else
      select_from_diff
    fi
    ;;
  *) echo "::error::unknown mode ${MODE}"; exit 1 ;;
esac
