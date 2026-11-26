#!/bin/bash
# launch-persona-auto.sh
# Non-interactive persona launcher for GitHub Actions automation.
# Copy this file and replace all placeholders marked with <REPLACE> before use.
#
# Usage: <project>-<persona>-auto.sh "prompt text"
#
# For interactive manual sessions use launch-persona.sh instead.
#
# Every run gets its own container name, so it never collides with an
# interactive session or with a container left behind by an earlier run.
# The calling workflow (persona-run.yml) sets PERSONA_CONTAINER_NAME so its cleanup step can
# remove the container even if this script is killed outright; when unset, a
# unique name is generated. The container is also removed when this script
# exits or is interrupted (for example by a workflow step timeout).

COMPOSE_FILE="/mnt/e/docker/<REPLACE:project-persona>/docker-compose.yml"
SERVICE="claude-<REPLACE:project-persona>"

if [ -z "$1" ]; then
  echo "Error: prompt argument required."
  echo "Usage: <REPLACE:project-persona>-auto.sh \"your prompt here\""
  exit 1
fi

CONTAINER_NAME="${PERSONA_CONTAINER_NAME:-$SERVICE-auto-$(date +%s)-$$}"
PERSONA_PID=""

cleanup() {
  [ -n "$PERSONA_PID" ] && kill "$PERSONA_PID" > /dev/null 2>&1
  docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'echo "Launcher interrupted - removing container $CONTAINER_NAME" >&2; exit 130' INT
trap 'echo "Launcher terminated - removing container $CONTAINER_NAME" >&2; exit 143' TERM

# Run in the background and wait, so a signal is handled immediately
# instead of after the persona finishes. -T and /dev/null: no terminal here.
docker compose \
  -f "$COMPOSE_FILE" \
  run --rm -T --name "$CONTAINER_NAME" "$SERVICE" \
  --dangerously-skip-permissions \
  -p "$1" < /dev/null &
PERSONA_PID=$!
wait "$PERSONA_PID"
PERSONA_STATUS=$?
# Cleared so the EXIT trap never signals a recycled PID
PERSONA_PID=""
exit $PERSONA_STATUS
