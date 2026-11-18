#!/usr/bin/env bash
# Merges the open Release Please pull request of REPO when main is still TESTED, every check of the
# pull request's head passed, and it changes only release metadata within one major version and
# lists no breaking change.
set -euo pipefail

api() {
  curl -fsSL -H "Authorization: Bearer ${GH_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" "${GITHUB_API_URL:-https://api.github.com}/repos/${REPO}/$1" "${@:2}"
}
version() {
  api "contents/.release-please-manifest.json?ref=$1" -H "Accept: application/vnd.github.raw+json" \
    | jq -r '.["."]'
}

prs=$(api "pulls?state=open&base=main&head=${REPO%%/*}:release-please--branches--main")
case "$(jq length <<< "${prs}")" in
  0) echo "No release is waiting."; exit 0 ;;
  1) pr=$(jq '.[0]' <<< "${prs}") ;;
  *) echo "::error::several open release pull requests; merge one by hand."; exit 1 ;;
esac
if [ "$(jq -r '.head.repo.full_name' <<< "${pr}")" != "${REPO}" ] \
  || [ "$(jq -r '.head.ref' <<< "${pr}")" != release-please--branches--main ]; then
  echo "::error::the release pull request does not come from ${REPO}:release-please--branches--main"
  exit 1
fi
number=$(jq -r .number <<< "${pr}")
base=$(jq -r .base.sha <<< "${pr}")
head=$(jq -r .head.sha <<< "${pr}")

if [ "$(api commits/main | jq -r .sha)" != "${TESTED}" ]; then
  echo "::notice::main moved after ${TESTED} was tested; the next run releases #${number}."
  exit 0
fi
checks=$(api "commits/${head}/check-runs?per_page=100")
total=$(jq .total_count <<< "${checks}")
if [ "${total}" -eq 0 ]; then
  echo "::error::#${number} has no checks on ${head}; merge it by hand once they are green."
  exit 1
fi
if [ "${total}" -gt "$(jq '.check_runs | length' <<< "${checks}")" ]; then
  echo "::error::#${number} has more than 100 checks; merge it by hand once they are green."
  exit 1
fi
red=$(jq -r '.check_runs[] | select(.status == "completed" and (.conclusion | IN("success", "neutral", "skipped") | not)) | .name' <<< "${checks}")
if [ -n "${red}" ]; then
  echo "::error::#${number} has failed checks: ${red//$'\n'/, }"
  exit 1
fi
if jq -e 'any(.check_runs[]; .status != "completed")' <<< "${checks}" > /dev/null; then
  echo "::notice::the checks of #${number} are still running; the next run releases it."
  exit 0
fi
compare=$(api "compare/${base}...${head}")
files=$(jq -er 'if (.files | length) > 0 and (.files | length) < 300 then .files[].filename else error("no complete file list") end' <<< "${compare}")
other=$(grep -v -x -E 'CHANGELOG\.md|\.release-please-manifest\.json|galaxy\.yml|(.+/)?version\.txt' <<< "${files}" || true)
if [ -n "${other}" ]; then
  echo "::error::#${number} changes more than release metadata: ${other//$'\n'/ }"
  exit 1
fi

old=$(version "${TESTED}")
new=$(version "${head}")
for v in "${old}" "${new}"; do
  if ! [[ ${v} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "::error::release version ${v} is not MAJOR.MINOR.PATCH; merge #${number} by hand."
    exit 1
  fi
done
if [ "${old%%.*}" != "${new%%.*}" ]; then
  echo "::notice::${old} -> ${new} is a major release; merge #${number} by hand."
  exit 0
fi
if jq -r '.body // ""' <<< "${pr}" | grep -q -i 'BREAKING CHANGE'; then
  echo "::notice::${new} lists breaking changes; merge #${number} by hand."
  exit 0
fi
api "pulls/${number}/merge" -X PUT -d "{\"merge_method\":\"squash\",\"sha\":\"${head}\"}" > /dev/null
echo "Merged #${number}: ${old} -> ${new}"
