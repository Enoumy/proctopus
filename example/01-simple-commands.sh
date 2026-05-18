#!/usr/bin/env bash

set -eou pipefail

export VAR=123

function my_function() {
  VAR2=456
  echo "this is a bash function VAR=${VAR} VAR2=${VAR2}"
}

export -f my_function

exec proctopus \
  -title "$(basename "$0")" \
  'loops/seq/10:seq 10' \
  -n 'date:date' \
  -n 'echo hello:echo hello' \
  -n 'loops/yes:yes' \
  -n 'loops/seq/100:seq 100' \
  -n 'loops/seq/1000:seq 1000' \
  'network/ping localhost:ping localhost' \
  -n 'network/curl example:curl -s https://example.com | head -5' \
  -n 'long command:curl -v -e -s https://example.com x https://example.com -foo -bar | head -5 | sed -nE -e "s/foo/bar/"' \
  -n 'sleep 5:sleep 5' \
  'false:false' \
  -n 'custom:my_function' \
  -n 'slow death:trap "echo dying; sleep 2" TERM; echo sleeping; sleep infinity' \
  "$@"
