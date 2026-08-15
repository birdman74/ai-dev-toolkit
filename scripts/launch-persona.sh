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
#  --dangerously-skip-permissions  # ONLY ENABLE THIS OPTION WHEN SANDBOXING HAS BEEN SETUP, TESTED, AND PERSONA SCOPE FOR THE CONTAINER IS LIMITED AND APPROVED