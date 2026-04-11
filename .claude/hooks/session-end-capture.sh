#!/bin/bash
# Hook: session-end-capture
# Fires at Stop (session ending). Best-effort: may not fire on forced close.
# Prompts Claude to write a draft if work was done but no drafts exist.

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

DRAFTS_DIR="meta/drafts"
[ -d "$DRAFTS_DIR" ] || exit 0

# Check if ANY drafts exist (not just today — avoids midnight edge case)
DRAFT_COUNT=$(find "$DRAFTS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

# Check if there are uncommitted changes (indicates work was done)
CHANGED=$(git status --porcelain --no-renames 2>/dev/null | grep -v '\.claude/' | grep -v 'meta/drafts/' | wc -l | tr -d ' ')

if [ "$DRAFT_COUNT" -eq 0 ] && [ "$CHANGED" -gt 0 ]; then
  cat <<'JSON'
{
  "systemMessage": "📝 SESSION ENDING. There are uncommitted changes but no drafts.\n\nWrite a draft to meta/drafts/ before context is lost:\n- What decisions were made and WHY?\n- What was considered and REJECTED?\n- What problems were discovered?\n- What questions remain open?\n\nCommand: /draft"
}
JSON
elif [ "$DRAFT_COUNT" -gt 0 ]; then
  cat <<'JSON'
{
  "systemMessage": "📝 Session ending. Drafts exist (meta/drafts/). Check: are all decisions from this session recorded?"
}
JSON
fi

exit 0
