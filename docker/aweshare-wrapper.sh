#!/bin/sh
# Container-local `aweshare` command. The image ships the hub only, so the
# umbrella CLI is a thin wrapper that forwards to the hub CLI. `aweshare hub X`
# and plain `X` both work; -h/--help/help, -v/--version and no args print the
# hub usage; `producer`/`consumer` are rejected (they run on their own machines).
case "$1" in
  hub) shift; exec node /app/apps/hub/dist/cli.js "$@" ;;
  ""|-h|--help|help|-v|--version) exec node /app/apps/hub/dist/cli.js "${1:--h}" ;;
  producer) echo "error: producer commands run on the producer machine, not in the hub container" >&2; exit 1 ;;
  consumer) echo "error: consumer commands run on the consumer machine, not in the hub container" >&2; exit 1 ;;
esac
echo "error: use \"aweshare hub <command>\" in this container; producer/consumer commands run on their own machines" >&2
exit 1
