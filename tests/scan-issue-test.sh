#!/usr/bin/env bash
# Runs the scan-issue action's script against a fake GitHub API, a curl on PATH that answers from
# fixture files and records writes, and checks what it does for each scan result.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

script=${root}/.github/actions/scan-issue/scan-issue.sh
api=${work}/api
mkdir -p "${work}/bin"
cat > "${work}/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
url='' method=GET data=''
while [ "$#" -gt 0 ]; do
  case $1 in
    -X) method=$2; shift ;;
    -d) data=$2; shift ;;
    -H) shift ;;
    http*) url=$1 ;;
  esac
  shift
done
path=${url#"${GITHUB_API_URL}/repos/${REPO}/"}
if [ "${method}" != GET ]; then
  echo "${method} ${path} $(jq -c . <<< "${data}")" >> "${FAKE_API}/writes"
  echo '{}'
  exit 0
fi
file=${FAKE_API}/$(tr '/?&=:.' '______' <<< "${path}")
if [ ! -f "${file}" ]; then
  echo "curl: (22) The requested URL returned error: 404 ${path}" >&2
  exit 22
fi
cat "${file}"
EOF
chmod +x "${work}/bin/curl"

repo=sessrumnir/images
title="Image scan: published images have fixable vulnerabilities"
run=https://github.com/${repo}/actions/runs/42
issues="issues?state=open&per_page=100"
jobs="actions/runs/42/attempts/1/jobs?per_page=100"
failures=0

serve() {
  cat > "${api}/$(tr '/?&=:.' '______' <<< "$1")"
}

# No open scan issue; trivy failed on cosign, passed on crane.
night() {
  rm -rf "${api}"
  mkdir -p "${api}"
  jq -n '[{number: 3, title: "Dependency Dashboard"}, {number: 4, title: "Image scan: published images have fixable vulnerabilities", pull_request: {}}]' \
    | serve "${issues}"
  jq -n '{jobs: [
    {name: "scan / images", conclusion: "success", html_url: "u/1"},
    {name: "scan / scan (cosign)", conclusion: "failure", html_url: "u/2"},
    {name: "scan / scan (crane)", conclusion: "success", html_url: "u/3"},
    {name: "scan / report", conclusion: null, html_url: "u/4"}]}' | serve "${jobs}"
}

open_issue() {
  jq -n --arg title "${title}" '[{number: 3, title: "Dependency Dashboard"}, {number: 9, title: $title}]' | serve "${issues}"
}

check() {
  local name=$1 result=$2 expected=$3 writes=$4 got status=0 did=none
  got=$(PATH="${work}/bin:${PATH}" FAKE_API=${api} GITHUB_API_URL=https://api.test GH_TOKEN=t \
    REPO=${repo} RESULT=${result} RUN_ID=42 RUN_ATTEMPT=1 bash "${script}" 2>&1 | tail -n 1) || status=$?
  if [ -f "${api}/writes" ]; then
    did=$(cat "${api}/writes")
  fi
  if [ "${got}" = "${expected}" ] && [ "${did}" = "${writes}" ]; then
    echo "ok    ${name}"
  else
    echo "FAIL  ${name}: expected '${expected}' and writes '${writes}', got '${got}' (exit ${status}) and writes '${did}'"
    failures=$((failures + 1))
  fi
}

body() {
  jq -cn --arg run "${run}" --arg failed "$1" \
    '{body: "The scan of the published images failed in \($run): fixable HIGH or CRITICAL vulnerabilities, or a scan error.\n\n\($failed)\n\nFix it with a version or base image bump in a pull request, not a rebuild."}'
}

night
check "a failure opens the issue" failure "Opened an issue." \
  "POST issues $(body '- [cosign](u/2)' | jq -c --arg title "${title}" '. + {title: $title}')"

night
open_issue
check "a failure comments on the open issue" failure "Commented on #9." \
  "POST issues/9/comments $(body '- [cosign](u/2)')"

night
jq -n '{jobs: [
  {name: "nightly / scan / scan (cosign)", conclusion: "failure", html_url: "u/2"},
  {name: "nightly / scan / scan (trivy)", conclusion: "failure", html_url: "u/5"}]}' | serve "${jobs}"
check "two failed images under a nested caller" failure "Opened an issue." \
  "POST issues $(body $'- [cosign](u/2)\n- [trivy](u/5)' | jq -c --arg title "${title}" '. + {title: $title}')"

night
jq -n '{jobs: [{name: "scan / report", conclusion: "failure", html_url: "u/4"}]}' | serve "${jobs}"
check "no failed scan job found" failure "Opened an issue." \
  "POST issues $(body '- no scan job reported a failure; see the run' | jq -c --arg title "${title}" '. + {title: $title}')"

night
open_issue
check "a clean scan closes the open issue" success "Closed #9." \
  "POST issues/9/comments {\"body\":\"Clean again in ${run}.\"}
PATCH issues/9 {\"state\":\"closed\",\"state_reason\":\"completed\"}"

night
check "a clean scan without an issue" success "Every image is clean." none

night
check "an unknown result" cancelled "::error::result must be success or failure, not cancelled" none

[ "${failures}" -eq 0 ] || { echo "${failures} case(s) failed"; exit 1; }
