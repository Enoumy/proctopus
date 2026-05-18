#!/usr/bin/env bash

set -eou pipefail

function start-server () {
  exec socat -v tcp-listen:23450,fork,reuseaddr exec:date
}

function start-client () {
  while true; do
    nc localhost 23450 --recv-only
    sleep 1
  done
}

export -f start-server
export -f start-client

exec proctopus \
  -title "$(basename "$0")" \
  'server:start-server' \
  'client:start-client' \
  -n 'status:nc localhost 23450 --recv-only' \
  "$@"
