#!/usr/bin/env bash

set -eou pipefail

exec proctopus \
  -title "$(basename "$0")" \
  "one/foo:echo foo" \
  "one/bar:echo bar" \
  "two/foo:echo foo" \
  "two/bar:echo bar" \
  -g "three:sleep 2; proctopus 'foo:echo foo' 'bar: echo bar'" \
  -g "four:sleep 1; proctopus 'a/foo:echo foo' 'b/bar: echo bar'" \
  -collapse one \
  -collapse three \
  -collapse four/a \
  -collapse unknown \
  "$@"
