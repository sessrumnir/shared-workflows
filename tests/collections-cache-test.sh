#!/usr/bin/env bash
# Runs the collections-cache action's script in scratch collection checkouts whose `make deps`
# counts its calls, and checks misses, hits, the stored entry and the pruning.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

script=${root}/.github/actions/collections-cache/collections-cache.sh
cache=${work}/cache/sessrumnir-collections
failures=0

checkout() {
  local dir=${work}/$1
  rm -rf "${dir}"
  mkdir -p "${dir}"
  printf 'collections:\n  - name: community.docker\n    version: %s\n' "$2" > "${dir}/requirements.yml"
  cat > "${dir}/makefile" << 'EOF'
deps:
	echo call >> ../deps-calls
	mkdir -p .ansible/collections/ansible_collections/community/docker .ansible/collections/ansible_collections/sessrumnir
	cp requirements.yml .ansible/collections/ansible_collections/community/docker/MANIFEST
	ln -sfn ../../../.. .ansible/collections/ansible_collections/sessrumnir/self
EOF
}

run() {
  (cd "${work}/$1" && XDG_CACHE_HOME=${work}/cache bash "${script}" 2>&1 | tail -n 1)
}

calls() {
  if [ -f "${work}/deps-calls" ]; then wc -l < "${work}/deps-calls"; else echo 0; fi
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

checkout one 5.4.0
key=$(sha256sum "${work}/one/requirements.yml" | cut -c1-32)
check "miss stores the entry" "collections for requirements.yml ${key} stored in the runner cache" "$(run one)"
check "miss runs make deps" 1 "$(calls)"
check "entry holds the installed collection" 5.4.0 "$(sed -n 's/.*version: //p' "${cache}/${key}/community/docker/MANIFEST")"
check "entry leaves out the collection's own link" "" "$(find "${cache}/${key}" -type l)"

checkout two 5.4.0
check "hit restores" "collections for requirements.yml ${key} restored from the runner cache" "$(run two)"
check "hit skips make deps" 1 "$(calls)"
check "hit installs the collection" 5.4.0 \
  "$(sed -n 's/.*version: //p' "${work}/two/.ansible/collections/ansible_collections/community/docker/MANIFEST")"

touch -d '15 days ago' "${cache}/${key}"
checkout three 5.5.0
run three > /dev/null
check "another requirements.yml misses" 2 "$(calls)"
check "a store prunes entries unused for 14 days" 1 "$(find "${cache}" -mindepth 1 -maxdepth 1 | wc -l)"

checkout four 5.5.0
rm "${work}/four/requirements.yml"
check "no requirements.yml" "no requirements.yml, nothing to cache" "$(run four)"
check "no requirements.yml skips make deps" 2 "$(calls)"

[ "${failures}" -eq 0 ]
