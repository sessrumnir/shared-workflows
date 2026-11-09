#!/usr/bin/env bash
# Runs the select-images action's script against a scratch repository and checks the images it
# picks for each kind of change.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

script=${root}/.github/actions/select-images/select-images.sh
zeros=0000000000000000000000000000000000000000

repo=${work}/repo
git init -q -b main "${repo}"
for image in alpha beta gamma; do
  mkdir -p "${repo}/images/${image}" "${repo}/${image}"
  echo FROM scratch > "${repo}/images/${image}/Containerfile"
  echo FROM scratch > "${repo}/${image}/Containerfile"
done
mkdir -p "${repo}/images/notes"
echo notes > "${repo}/images/notes/README.md"
git -C "${repo}" add -A
git -C "${repo}" -c user.name=t -c user.email=t@example.com commit -q -m base
base=$(git -C "${repo}" rev-parse HEAD)
failures=0

check() {
  local name=$1 expected=$2 mode=$3 directory=$4 from=$5
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
  local got head
  head=$(git -C "${repo}" rev-parse HEAD)
  if [ "${from}" = base ]; then
    from=${base}
  fi
  got=$(cd "${repo}" && MODE=${mode} DIRECTORY=${directory} BASE=${from} HEAD=${head} \
    GITHUB_OUTPUT=/dev/null bash "${script}" 2>&1 | tail -n 1) || true
  if [ "${got}" = "${expected}" ]; then
    echo "ok    ${name}"
  else
    echo "FAIL  ${name}: expected '${expected}', got '${got}'"
    failures=$((failures + 1))
  fi
}

all='images: ["alpha","beta","gamma"]'
check "all" "${all}" all images base images/alpha/Containerfile
check "no base" "${all}" auto images "" images/alpha/Containerfile
check "new branch" "${all}" auto images "${zeros}" images/alpha/Containerfile
check "one image" 'images: ["alpha"]' auto images base images/alpha/Containerfile images/alpha/x.sh
check "two images" 'images: ["alpha","gamma"]' auto images base images/gamma/x images/alpha/x
check "a directory without a Containerfile" 'images: []' auto images base images/notes/README.md
check "a deleted image" 'images: []' auto images base images/delta/x
check "other files" 'images: []' auto images base README.md alpha/Containerfile
check "hadolint config" "${all}" auto images base .hadolint.yaml
check "trailing slash" 'images: ["beta"]' auto images/ base images/beta/x
check "top level" 'images: ["beta"]' auto . base beta/x images/alpha/x
check "unknown mode" "::error::mode must be auto or all, not some" some images base
check "a directory with dots" "::error::directory must be . or a relative path without dots, not ../images" auto ../images base

[ "${failures}" -eq 0 ] || { echo "${failures} case(s) failed"; exit 1; }
