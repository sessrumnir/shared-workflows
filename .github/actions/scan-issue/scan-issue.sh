#!/usr/bin/env bash
# Keeps one open issue for the published images' scan in REPO: a failed scan opens it or comments
# the failed images and the run on it, a successful one closes it.
set -euo pipefail

title="Image scan: published images have fixable vulnerabilities"
api() {
  curl -fsSL -H "Authorization: Bearer ${GH_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" "${GITHUB_API_URL:-https://api.github.com}/repos/${REPO}/$1" "${@:2}"
}
post() {
  api "$1" -X "${3:-POST}" -H "Content-Type: application/json" -d "$2" > /dev/null
}

case "${RESULT}" in
  success | failure) ;;
  *) echo "::error::result must be success or failure, not ${RESULT}"; exit 1 ;;
esac
run="${GITHUB_SERVER_URL:-https://github.com}/${REPO}/actions/runs/${RUN_ID}"
number=$(api "issues?state=open&per_page=100" \
  | jq -r --arg title "${title}" '[.[] | select(.title == $title and (has("pull_request") | not))][0].number // empty')

if [ "${RESULT}" = success ]; then
  if [ -n "${number}" ]; then
    post "issues/${number}/comments" "$(jq -n --arg run "${run}" '{body: "Clean again in \($run)."}')"
    post "issues/${number}" '{"state": "closed", "state_reason": "completed"}' PATCH
    echo "Closed #${number}."
  else
    echo "Every image is clean."
  fi
  exit 0
fi

failed=$(api "actions/runs/${RUN_ID}/attempts/${RUN_ATTEMPT}/jobs?per_page=100" \
  | jq -r '.jobs[] | select(.conclusion == "failure") | (.name | capture("(^|/ )scan \\((?<image>[^)]+)\\)$").image) as $image
      | "- [\($image)](\(.html_url))"')
body=$(jq -n --arg run "${run}" --arg failed "${failed:-- no scan job reported a failure; see the run}" \
  '{body: "The scan of the published images failed in \($run): fixable HIGH or CRITICAL vulnerabilities, or a scan error.\n\n\($failed)\n\nFix it with a version or base image bump in a pull request, not a rebuild."}')
if [ -n "${number}" ]; then
  post "issues/${number}/comments" "${body}"
  echo "Commented on #${number}."
else
  post issues "$(jq --arg title "${title}" '. + {title: $title}' <<< "${body}")"
  echo "Opened an issue."
fi
