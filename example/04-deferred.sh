#!/usr/bin/env bash

set -eou pipefail

function level {
  sleep 1
  if [[ $1 -eq 0 ]]; then
    exec proctopus "sleep:sleep infinity"
  else
    exec proctopus "sleep:sleep $1 && echo $1" -g "L$1:level $(( $1 - 1 ))"
  fi
}

export -f level

exec proctopus -title "$(basename "$0")" -g "root:level 5" -s root/L5/sleep "$@"
