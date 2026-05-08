#!/bin/bash

# Shared helpers for Mezz container entrypoints. Source via:
#   . /usr/local/lib/mezz/helpers.sh
# Set LOG_TAG before sourcing (or before calling log) to namespace messages.

# log <level> <message...>
# Emit a logfmt line:
#   ts=<RFC3339> level=<level> svc=<LOG_TAG> msg="<message>"
# Levels: debug, info, warn, error.
log() {
  local level=$1
  shift
  local msg="$*"

  msg=${msg//\"/\\\"}
  printf 'ts=%s level=%s svc=%s msg="%s"\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$level" \
    "${LOG_TAG:-app}" \
    "$msg"
}

# require_var <NAME> [<NAME>...]
# Exit if any named env var is unset or empty. Reports all missing vars
# in one pass so the caller fixes them together.
require_var() {
  local missing=0 name
  for name in "$@"; do
    if [ -z "${!name:-}" ]; then
      log error "required env var '$name' is unset or empty"
      missing=1
    fi
  done

  [ "$missing" -eq 0 ] || exit 1
}
