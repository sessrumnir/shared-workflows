#!/usr/bin/env bash
# Runs the image-load and image-push actions' scripts against a fake docker on PATH that records
# its calls, and checks what each hand-off (CI registry digest or tarball) does.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

load=${root}/.github/actions/image-load/load.sh
push=${root}/.github/actions/image-push/push.sh
mkdir -p "${work}/bin"
cat > "${work}/bin/docker" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
if [ "$1" = --config ]; then
  shift 2
fi
case "$1 ${2:-}" in
  "login "*) cat > /dev/null; echo "login $2" >> "${FAKE}/calls" ;;
  "pull "*)
    echo "pull ${*: -1}" >> "${FAKE}/calls"
    grep -qxF -- "${*: -1}" "${FAKE}/pullable" ;;
  "image inspect")
    if [ "$4" = '{{json .RepoDigests}}' ]; then
      jq -cn --arg digest "${CI_IMAGE}@sha256:$(printf 'c%.0s' {1..64})" '[$digest]'
    else
      echo "${REF}@sha256:$(printf 't%.0s' {1..64})" | tr t a
    fi ;;
  "save "*) touch "$3"; echo "save $3 $4" >> "${FAKE}/calls" ;;
  "run "*)
    args=("$@")
    for i in "${!args[@]}"; do
      if [ "${args[i]}" = "${CRANE}" ]; then
        echo "crane ${args[*]:i+1}" >> "${FAKE}/calls"
      fi
    done ;;
  *) echo "$*" >> "${FAKE}/calls" ;;
esac
FAKE
chmod +x "${work}/bin/docker"

ref=ghcr.io/sessrumnir/crane
ci=registry.test/sessrumnir-ci/images/crane
sha=sha256:$(printf 'c%.0s' {1..64})
failures=0

run() {
  local script=$1 handoff=$2
  : > "${work}/output"
  : > "${work}/calls"
  PATH="${work}/bin:${PATH}" FAKE=${work} GITHUB_OUTPUT=${work}/output RUNNER_TEMP=${work}/temp \
    GITHUB_RUN_ID=42 GITHUB_RUN_ATTEMPT=2 HANDOFF=${handoff} REF=${ref} CI_IMAGE=${ci} \
    CONFIG=${work}/docker OUTPUT=${work}/image IMAGE=${work}/image CRANE=crane-image TOKEN=t ACTOR=a \
    bash "${script}" 2>&1 | tail -n 1 || true
}

check() {
  local name=$1 expected=$2 got=$3
  got=$(sed -E 's/[0-9]{14}/<time>/g' <<< "${got}")
  if [ "${got}" = "${expected}" ]; then
    echo "ok    ${name}"
  else
    echo "FAIL  ${name}:"
    diff <(echo "${expected}") <(echo "${got}") || true
    failures=$((failures + 1))
  fi
}

fresh() {
  rm -rf "${work}/image" "${work}/temp"
  mkdir -p "${work}/image" "${work}/temp"
  : > "${work}/pullable"
}

fresh
touch "${work}/image/image.tar"
run "${load}" cache > /dev/null
check "load: a tarball" "load --input ${work}/image/image.tar" "$(cat "${work}/calls")"
check "load: scans the tarball" "tarball=${work}/image/image.tar" "$(cat "${work}/output")"

fresh
echo "${ci}:run-42-1" > "${work}/pullable"
run "${load}" registry > /dev/null
check "load: pulls the latest attempt that built" "pull ${ci}:run-42-2
pull ${ci}:run-42-1
tag ${ci}:run-42-1 ${ref}:stable
save ${work}/temp/scan/image.tar ${ref}:stable" "$(cat "${work}/calls")"
check "load: records the digest" "${ci}@${sha}" "$(cat "${work}/image/digest")"
check "load: scans a saved tarball" "tarball=${work}/temp/scan/image.tar" "$(cat "${work}/output")"

fresh
check "load: nothing built" "::error::no ${ci}:run-42-<attempt> in the CI registry" "$(run "${load}" registry)"

fresh
printf '1.2' > "${work}/image/version"
printf '%s' "${ci}@${sha}" > "${work}/image/digest"
run "${push}" registry > /dev/null
check "push: copies the CI registry digest" "login ghcr.io
crane copy ${ci}@${sha} ${ref}:stable
crane tag ${ref}@${sha} 1.2-<time>
crane tag ${ref}@${sha} 1.2" "$(cat "${work}/calls")"
check "push: outputs the same digest" "digest=${ref}@${sha}" "$(cat "${work}/output")"

fresh
printf '' > "${work}/image/version"
printf '%s' "registry.test/other/crane@${sha}" > "${work}/image/digest"
check "push: refuses another repository's digest" \
  "::error::unexpected CI registry digest registry.test/other/crane@${sha}" "$(run "${push}" registry)"

fresh
printf '' > "${work}/image/version"
touch "${work}/image/image.tar"
run "${push}" cache > /dev/null
check "push: loads and pushes a tarball" "login ghcr.io
load --input ${work}/image/image.tar
tag ${ref}:stable ${ref}:stable
push ${ref}:stable
tag ${ref}:stable ${ref}:<time>
push ${ref}:<time>" "$(cat "${work}/calls")"
check "push: outputs the pushed digest" "digest=${ref}@sha256:$(printf 'a%.0s' {1..64})" "$(cat "${work}/output")"

fresh
printf 'v1' > "${work}/image/version"
check "push: refuses a bad version" "::error::version v1, expected digits and dots" "$(run "${push}" cache)"

[ "${failures}" -eq 0 ] || { echo "${failures} case(s) failed"; exit 1; }
