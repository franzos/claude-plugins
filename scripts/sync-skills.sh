#!/bin/sh
# Sync shared skills into every plugin.
#
# The canonical source for a shared skill is shared/<skill>/. Each plugin must
# ship its own copy under plugins/<plugin>/skills/<skill>/ because plugins are
# installed independently. Those copies are generated artifacts: edit the
# master under shared/, then run this script to propagate the change.
#
#   scripts/sync-skills.sh           copy shared/* into every plugin
#   scripts/sync-skills.sh --check   report drift without writing (exit 1 if any)
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
src_root="$repo_root/shared"
check=0
[ "${1:-}" = "--check" ] && check=1

status=0
for plugin_dir in "$repo_root"/plugins/*/; do
  for skill_src in "$src_root"/*/; do
    skill=$(basename "$skill_src")
    dest="$plugin_dir""skills/$skill"
    if [ "$check" -eq 1 ]; then
      if ! diff -r "$skill_src" "$dest" >/dev/null 2>&1; then
        echo "drift: $dest differs from shared/$skill"
        status=1
      fi
    else
      mkdir -p "$plugin_dir""skills"
      rm -rf "$dest"
      cp -R "$skill_src" "$dest"
      echo "synced: $dest"
    fi
  done
done

exit $status
