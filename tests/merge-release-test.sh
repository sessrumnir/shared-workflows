#!/usr/bin/env bash
# Runs the merge-release action's script against a fake GitHub API, a curl on PATH that answers
# from fixture files and records merges, and checks what it decides for each release state.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

script=${root}/.github/actions/merge-release/merge-release.sh
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
if [ "${method}" = PUT ]; then
  echo "${path} ${data}" >> "${FAKE_API}/merged"
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

repo=sessrumnir/ansible-x
tested=1111111111111111111111111111111111111111
base=2222222222222222222222222222222222222222
head=3333333333333333333333333333333333333333
pulls="pulls?state=open&base=main&head=sessrumnir:release-please--branches--main"
failures=0

serve() {
  cat > "${api}/$(tr '/?&=:.' '______' <<< "$1")"
}

pr() {
  jq -n --arg repo "${1:-${repo}}" --arg ref "${2:-release-please--branches--main}" --arg body "${3:-}" \
    --arg base "${base}" --arg head "${head}" \
    '{number: 7, body: $body, base: {sha: $base}, head: {sha: $head, ref: $ref, repo: {full_name: $repo}}}'
}

files() {
  jq -cn '{files: [$ARGS.positional[] | {filename: .}]}' --args "$@"
}

# A release from 0.4.1 to 0.5.0 that main, still at the tested commit, is waiting for.
release() {
  rm -rf "${api}"
  mkdir -p "${api}"
  pr | jq -s . | serve "${pulls}"
  echo "{\"sha\": \"${tested}\"}" | serve commits/main
  files CHANGELOG.md .release-please-manifest.json galaxy.yml | serve "compare/${base}...${head}"
  echo '{".": "0.4.1"}' | serve "contents/.release-please-manifest.json?ref=${tested}"
  echo '{".": "0.5.0"}' | serve "contents/.release-please-manifest.json?ref=${head}"
}

check() {
  local name=$1 expected=$2 merged=$3 got status=0 did=no
  got=$(PATH="${work}/bin:${PATH}" FAKE_API=${api} GITHUB_API_URL=https://api.test GH_TOKEN=t \
    REPO=${repo} TESTED=${tested} bash "${script}" 2>&1 | tail -n 1) || status=$?
  if [ -f "${api}/merged" ]; then
    did=$(cat "${api}/merged")
  fi
  if [ "${got}" = "${expected}" ] && [ "${did}" = "${merged}" ]; then
    echo "ok    ${name}"
  else
    echo "FAIL  ${name}: expected '${expected}' and merge '${merged}', got '${got}' (exit ${status}) and merge '${did}'"
    failures=$((failures + 1))
  fi
}

merge="pulls/7/merge {\"merge_method\":\"squash\",\"sha\":\"${head}\"}"

release
check "a tested release" "Merged #7: 0.4.1 -> 0.5.0" "${merge}"

release
echo '[]' | serve "${pulls}"
check "no release" "No release is waiting." no

release
{ pr; pr; } | jq -s . | serve "${pulls}"
check "two releases" "::error::several open release pull requests; merge one by hand." no

release
pr someone/ansible-x | jq -s . | serve "${pulls}"
check "from a fork" "::error::the release pull request does not come from ${repo}:release-please--branches--main" no

release
pr "${repo}" other | jq -s . | serve "${pulls}"
check "another branch" "::error::the release pull request does not come from ${repo}:release-please--branches--main" no

release
echo '{"sha": "4444444444444444444444444444444444444444"}' | serve commits/main
check "main moved" "::notice::main moved after ${tested} was tested; the next run releases #7." no

release
files CHANGELOG.md roles/x/tasks/main.yml plugins/x.py | serve "compare/${base}...${head}"
check "more than metadata" "::error::#7 changes more than release metadata: roles/x/tasks/main.yml plugins/x.py" no

release
files | serve "compare/${base}...${head}"
check "no file list" "jq: error (at <stdin>:1): no complete file list" no

release
echo '{".": "1.0.0"}' | serve "contents/.release-please-manifest.json?ref=${head}"
check "a major release" "::notice::0.4.1 -> 1.0.0 is a major release; merge #7 by hand." no

release
echo '{".": "0.5.0-rc.1"}' | serve "contents/.release-please-manifest.json?ref=${head}"
check "not MAJOR.MINOR.PATCH" "::error::release version 0.5.0-rc.1 is not MAJOR.MINOR.PATCH; merge #7 by hand." no

release
pr "${repo}" release-please--branches--main $'### Features\n\n* **x:** BREAKING CHANGE: y' | jq -s . | serve "${pulls}"
check "a breaking change" "::notice::0.5.0 lists breaking changes; merge #7 by hand." no

[ "${failures}" -eq 0 ] || { echo "${failures} case(s) failed"; exit 1; }
