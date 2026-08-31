#!/bin/bash
# scripts/next-story.sh
# Determines the next eligible story from the GitHub Issues queue.
# Replace all <REPLACE:...> placeholders before use.
#
# Requires: gh CLI authenticated, GITHUB_TOKEN or GH_TOKEN set
# Usage: ./scripts/next-story.sh
# Output: story ID (e.g. "story-005") or empty if nothing eligible
# Exit 1: a story is already in-progress

SPECS_DIR="docs/specs"
REPO="<REPLACE:github-username>/<REPLACE:repo-name>"

# Check for story already in-progress
IN_PROGRESS=$(gh issue list \
  --repo "$REPO" \
  --label "story,in-progress" \
  --state open \
  --json number,title \
  --jq '.[0].title' 2>/dev/null)

if [ -n "$IN_PROGRESS" ]; then
  echo "ERROR: A story is already in-progress: $IN_PROGRESS" >&2
  exit 1
fi

# Get all open story issues sorted by number
OPEN_STORIES=$(gh issue list \
  --repo "$REPO" \
  --label "story" \
  --state open \
  --json number,title,labels \
  --jq '[.[] | select(.labels[].name == "story")] | sort_by(.number)' 2>/dev/null)

if [ -z "$OPEN_STORIES" ] || [ "$OPEN_STORIES" == "[]" ]; then
  echo ""
  exit 0
fi

# Get closed story titles for prerequisite checking
CLOSED_STORIES=$(gh issue list \
  --repo "$REPO" \
  --label "story" \
  --state closed \
  --json title \
  --jq '[.[].title]' 2>/dev/null)

STORY_COUNT=$(echo "$OPEN_STORIES" | jq length)

for i in $(seq 0 $((STORY_COUNT - 1))); do
  ISSUE_TITLE=$(echo "$OPEN_STORIES" | jq -r ".[$i].title")
  STORY_ID=$(echo "$ISSUE_TITLE" | grep -oP 'story-\d+')

  if [ -z "$STORY_ID" ]; then continue; fi

  SPEC_FILE=$(ls "$SPECS_DIR"/${STORY_ID}-*.md 2>/dev/null | head -1)
  if [ -z "$SPEC_FILE" ]; then continue; fi

  PREREQS=$(awk '/^## Prerequisites/{found=1; next} found && /^##/{exit} found{print}' "$SPEC_FILE" | grep -oP 'story-\d+')

  PREREQS_MET=true
  for PREREQ in $PREREQS; do
    PREREQ_CLOSED=$(echo "$CLOSED_STORIES" | jq -r ".[] | select(test(\"$PREREQ\"))" 2>/dev/null)
    if [ -z "$PREREQ_CLOSED" ]; then
      PREREQS_MET=false
      break
    fi
  done

  if [ "$PREREQS_MET" == "true" ]; then
    echo "$STORY_ID"
    exit 0
  fi
done

echo ""
exit 0
