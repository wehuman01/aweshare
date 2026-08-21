#!/bin/sh
# Container-local `aweshare` command. The image ships the hub only, so the
# umbrella CLI is a thin wrapper that forwards to the hub CLI. `aweshare hub X`
# and plain `X` both work; -h/--help/help, -v/--version and no args print the
# hub usage; `agent` is rejected (it runs on producer machines).
case "$1" in
  hub) shift; exec node /app/apps/hub/dist/cli.js "$@" ;;
  ""|-h|--help|help|-v|--version) exec node /app/apps/hub/dist/cli.js "${1:--h}" ;;
  agent) echo "error: the agent runs on the producer machine, not in the hub container" >&2; exit 1 ;;
esac
echo "error: use \"aweshare hub <command>\" or \"aweshare agent <command>\"" >&2
exit 1
