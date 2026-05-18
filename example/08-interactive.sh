#!/usr/bin/env bash

set -euo pipefail

example_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$example_dir/.." && pwd)"
export repo_dir

function shell () {
  exec "${SHELL:-bash}"
}

function readme () {
  exec less "$repo_dir/README.md"
}

export -f shell
export -f readme

exec proctopus \
  -title "$(basename "$0")" \
  -i 'shell:shell' \
  -i 'readme:readme' \
  -g 'nested:proctopus -i shell:shell -i readme:readme' \
  -i 'top:top' \
  -i 'exit/ok:echo ok' \
  -i 'exit/fail:echo err >&2; exit 1' \
  -i 'exit/slow:sleep 1; echo err >&2; exit 1' \
  "$@"
