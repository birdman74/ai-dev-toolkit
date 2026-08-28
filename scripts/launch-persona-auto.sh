#!/bin/bash
# launch-persona-auto.sh
# Non-interactive persona launcher for GitHub Actions automation.
# Copy this file and replace all placeholders marked with <REPLACE> before use.
#
# Usage: <project>-<persona>-auto.sh "prompt text"
#
# For interactive manual sessions use launch-persona.sh instead.
#
# See docs/new-project-setup.md for full setup instructions.

if [ -z "$1" ]; then
  echo "Error: prompt argument required."
  echo "Usage: <REPLACE:project-persona>-auto.sh \"your prompt here\""
  exit 1
fi

docker compose \
  -f /mnt/e/docker/<REPLACE:project-persona>/docker-compose.yml \
  run --rm claude-<REPLACE:project-persona> \
  --dangerously-skip-permissions \
  -p "$1"
