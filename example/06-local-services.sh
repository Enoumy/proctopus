#!/usr/bin/env bash

set -euo pipefail

function clock () {
  while true; do
    date
    sleep 1
  done
}

function worker () {
  local name="$1"
  local delay="$2"
  local i=0

  while true; do
    printf '%s processed item %d\n' "$name" "$i"
    i=$((i + 1))
    sleep "$delay"
  done
}

function health_check () {
  printf 'clock: ok\n'
  printf 'workers: ok\n'
}

export -f clock
export -f worker
export -f health_check

exec proctopus \
  -title "$(basename "$0")" \
  'services/clock:clock' \
  'workers/fast:worker fast 1' \
  'workers/slow:worker slow 3' \
  -n 'checks/health:health_check' \
  "$@"
