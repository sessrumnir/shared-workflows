#!/usr/bin/env bash
# Restores the collections that `make deps` installs from requirements.yml out of the runner's
# cache, keyed on the file's hash, so `make deps` finds them installed and asks no Galaxy server.
# On a miss it runs `make deps` and stores the result. Entries unused for 14 days are removed.
set -euo pipefail

if ! [ -f requirements.yml ]; then
  echo "no requirements.yml, nothing to cache"
  exit 0
fi
target=.ansible/collections/ansible_collections
cache=${XDG_CACHE_HOME:-${HOME}/.cache}/sessrumnir-collections
key=$(sha256sum requirements.yml | cut -c1-32)
entry=${cache}/${key}
mkdir -p "${cache}" "${target}"

if [ -d "${entry}" ] && touch "${entry}" && cp -a "${entry}/." "${target}/"; then
  echo "collections for requirements.yml ${key} restored from the runner cache"
  exit 0
fi

make deps
staging=$(mktemp -d "${cache}/.staging-XXXXXX")
trap 'rm -rf -- "${staging}"' EXIT
cp -a "${target}/." "${staging}/"
find "${staging}" -mindepth 2 -maxdepth 2 -type l -delete
if mv -T "${staging}" "${entry}" 2> /dev/null; then
  echo "collections for requirements.yml ${key} stored in the runner cache"
fi
find "${cache}" -mindepth 1 -maxdepth 1 -mtime +14 -exec rm -rf -- {} +
