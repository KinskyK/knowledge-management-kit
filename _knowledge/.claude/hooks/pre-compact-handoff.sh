#!/bin/bash
# Hook: pre-compact-handoff
# Fires before context compaction (PreCompact).
# Checks if WARM was already saved to sessions.md. If not — CRITICAL warning.
# If yes — soft reminder to verify completeness.

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

ROADMAP="meta/roadmap.md"
SESSIONS="meta/sessions.md"
[ ! -f "$ROADMAP" ] && exit 0

# Check if roadmap/sessions have uncommitted changes (WARM was written but not committed)
HAS_DIFF=false
git diff --quiet "$ROADMAP" 2>/dev/null || HAS_DIFF=true

# Check if roadmap was modified recently (mtime within last 2 hours)
RECENT_MODIFY=false
if [ "$(uname)" = "Darwin" ]; then
  MTIME=$(stat -f %m "$ROADMAP" 2>/dev/null)
else
  MTIME=$(stat -c %Y "$ROADMAP" 2>/dev/null)
fi
NOW=$(date +%s)
if [ -n "$MTIME" ] && [ $((NOW - MTIME)) -lt 7200 ]; then
  RECENT_MODIFY=true
fi

# Also check sessions.md
SESSIONS_DIFF=false
if [ -f "$SESSIONS" ]; then
  git diff --quiet "$SESSIONS" 2>/dev/null || SESSIONS_DIFF=true
  if [ "$(uname)" = "Darwin" ]; then
    SMTIME=$(stat -f %m "$SESSIONS" 2>/dev/null)
  else
    SMTIME=$(stat -c %Y "$SESSIONS" 2>/dev/null)
  fi
  if [ -n "$SMTIME" ] && [ $((NOW - SMTIME)) -lt 7200 ]; then
    SESSIONS_DIFF=true
  fi
fi

if [ "$HAS_DIFF" = true ] || [ "$RECENT_MODIFY" = true ] || [ "$SESSIONS_DIFF" = true ]; then
  # WARM was likely saved — soft reminder
  cat <<'JSON'
{
  "systemMessage": "⚠️ CONTEXT COMPRESSION. sessions.md / roadmap.md were updated recently — verify:\n1. Are all decisions recorded in decisions/?\n2. Is all research saved in docs/?\n3. Are HOT tasks current in roadmap?\n4. Is WARM recorded in sessions.md?\n5. Any unrecorded decisions? → /draft\nAfter verification — compression is safe."
}
JSON
else
  # WARM NOT saved — CRITICAL
  cat <<'JSON'
{
  "systemMessage": "🚨 CRITICAL: CONTEXT COMPRESSION, but sessions.md / roadmap.md were NOT updated!\nIMMEDIATELY:\n1. Write a decision draft → /draft\n2. Write current HOT (task, questions) to sessions.md\n3. Write WARM residual to meta/sessions.md\n4. Any unrecorded decisions → decisions/?\n5. Any unsaved research → docs/?\nOnly after recording is compression safe."
}
JSON
fi
