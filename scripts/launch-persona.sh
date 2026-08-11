#!/bin/bash
# Claude Code Persona Launcher — Template
#
# Copy this file and replace all placeholders marked with <REPLACE> before use.
# Place the completed script in ~/bin/ and make it executable:
#   chmod +x ~/bin/<REPLACE:project-persona>.sh
#
# See docs/new-project-setup.md for full setup instructions.

docker compose \
  -f /mnt/e/docker/<REPLACE:project-persona>/docker-compose.yml \
  run --rm claude-<REPLACE:project-persona>