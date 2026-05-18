#!/usr/bin/env bash

set -eou pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
logger="$script_dir/logger/main.exe"

exec proctopus \
  -title "$(basename "$0")" \
  "text-format:$logger" \
  "sexp-format:$logger -sexp" \
  "$@"
