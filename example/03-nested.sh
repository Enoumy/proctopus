#!/usr/bin/env bash

set -eou pipefail

root="$(readlink -f "$(dirname "$0")")"
self="$(readlink -f "$0")"
export root self

function inner {
  args=()
  for f in "$root"/*.sh; do
    # Don't recursively include this script
    [[ "$self" -ef "$f" ]] && continue

    args+=(-g "$(basename "$f"):$f")
  done

  exec proctopus "${args[@]}"
}

export -f inner

exec proctopus \
  -title "$(basename "$0")" \
  "outer:echo outer" \
  -g "inner:inner" \
  -g "error:echo 'oh no' >&2; exit 123" \
  -g "missing-proctopus-exec:echo 'not a group'" \
  "missing-group-flag:proctopus hello" \
  -g "never:sleep infinity" \
  "$@"
