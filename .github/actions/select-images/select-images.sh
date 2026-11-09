#!/usr/bin/env bash
# Writes images=<JSON list> to GITHUB_OUTPUT: every image directory under DIRECTORY with a
# Containerfile when MODE is all or BASE is unknown, else those the BASE...HEAD diff touches, and
# all of them when .hadolint.yaml changed.
set -euo pipefail

case "${MODE}" in
  auto | all) ;;
  *) echo "::error::mode must be auto or all, not ${MODE}"; exit 1 ;;
esac
if ! [[ ${DIRECTORY} =~ ^(\.|[A-Za-z0-9_-]+(/[A-Za-z0-9_-]+)*)/?$ ]]; then
  echo "::error::directory must be . or a relative path without dots, not ${DIRECTORY}"
  exit 1
fi
prefix="${DIRECTORY%/}/"
if [ "${prefix}" = ./ ]; then prefix=""; fi
all=$(for file in "${prefix}"*/Containerfile; do
        if [ -f "${file}" ]; then basename "$(dirname "${file}")"; fi
      done | jq -Rcs 'split("\n") | map(select(length > 0))')
if [ "${MODE}" = all ] || [ -z "${BASE}" ] || [ "${BASE}" = 0000000000000000000000000000000000000000 ]; then
  images=${all}
else
  images='[]'
  while IFS= read -r file; do
    if [[ ${file} == "${prefix}"* ]] && [[ ${file#"${prefix}"} =~ ^([^/]+)/ ]]; then
      images=$(jq -c --arg image "${BASH_REMATCH[1]}" '. + [$image] | unique' <<< "${images}")
    elif [ "${file}" = .hadolint.yaml ]; then
      images=${all}
      break
    fi
  done < <(git diff --name-only "${BASE}...${HEAD}")
  images=$(jq -c --argjson all "${all}" '[.[] | select(. as $image | $all | index($image))]' <<< "${images}")
fi
echo "images=${images}" >> "${GITHUB_OUTPUT}"
echo "images: ${images}"
