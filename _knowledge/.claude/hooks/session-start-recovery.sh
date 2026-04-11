#!/bin/bash
# Hook: session-start-recovery
# Fires at SessionStart. Checks for:
# 1. Uncommitted changes from previous session
# 2. Roadmap staleness (FAR monitoring)

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0
git rev-parse --git-dir > /dev/null 2>&1 || exit 0

OUTPUT=""

# --- Check 1: Uncommitted changes ---
CHANGED=$(git status --porcelain --no-renames 2>/dev/null | grep -v '\.claude/' | awk '{print $NF}')

if [ -n "$CHANGED" ]; then
  COUNT=$(echo "$CHANGED" | wc -l | tr -d ' ')
  OUTPUT="${OUTPUT}⚠️ PREVIOUS SESSION ENDED WITHOUT COMMIT.\n"
  OUTPUT="${OUTPUT}Uncommitted files: ${COUNT}\n\n"
  OUTPUT="${OUTPUT}$(echo "$CHANGED" | head -15)\n\n"
  OUTPUT="${OUTPUT}Recommendation: review git diff, update roadmap.md / sessions.md, commit.\n"
fi

# --- Check 2: Roadmap staleness (FAR monitoring) ---
ROADMAP="meta/roadmap.md"
if [ -f "$ROADMAP" ]; then
  # When was roadmap last committed?
  LAST_COMMIT_DATE=$(git log -1 --format="%ci" -- "$ROADMAP" 2>/dev/null)
  if [ -n "$LAST_COMMIT_DATE" ]; then
    LAST_COMMIT_TS=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$LAST_COMMIT_DATE" +%s 2>/dev/null || date -d "$LAST_COMMIT_DATE" +%s 2>/dev/null)
    NOW_TS=$(date +%s)
    if [ -n "$LAST_COMMIT_TS" ]; then
      HOURS_AGO=$(( (NOW_TS - LAST_COMMIT_TS) / 3600 ))
      if [ "$HOURS_AGO" -gt 48 ]; then
        OUTPUT="${OUTPUT}\n📋 roadmap.md was last updated ${HOURS_AGO}h ago.\n"
        OUTPUT="${OUTPUT}FAR audit may not have been run. Recommendation: run /far at session start.\n"
      fi
    fi
  fi
fi

# --- Check 3: Load last session context ---
SESSIONS="meta/sessions.md"
if [ -f "$SESSIONS" ]; then
  SESSION_COUNT=$(grep -c "^### Сессия" "$SESSIONS" 2>/dev/null || echo "0")
  LAST_SESSION=$(grep -n "^### Сессия" "$SESSIONS" | tail -1 | cut -d: -f1)
  if [ -n "$LAST_SESSION" ]; then
    OUTPUT="${OUTPUT}\n📋 Last session context (sessions.md):\n"
    OUTPUT="${OUTPUT}$(tail -n +$LAST_SESSION "$SESSIONS" | head -20)\n"
    if [ "$SESSION_COUNT" -gt 1 ]; then
      OUTPUT="${OUTPUT}\n📂 sessions.md has $((SESSION_COUNT - 1)) more blocks. If unclear or debating decision context — read earlier blocks (deep dive).\n"
    fi
  fi
fi

# --- Check 4: Pending drafts ---
DRAFTS_DIR="meta/drafts"
if [ -d "$DRAFTS_DIR" ]; then
  DRAFT_COUNT=$(find "$DRAFTS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$DRAFT_COUNT" -gt 0 ]; then
    OUTPUT="${OUTPUT}\n📝 Unprocessed drafts: ${DRAFT_COUNT} in meta/drafts/\n"
    OUTPUT="${OUTPUT}Formalize into ADR/sessions at next commit.\n"

    # Warn if drafts are older than 7 days
    OLD_DRAFTS=$(find "$DRAFTS_DIR" -maxdepth 1 -name "*.md" -mtime +7 2>/dev/null | wc -l | tr -d ' ')
    if [ "$OLD_DRAFTS" -gt 0 ]; then
      OUTPUT="${OUTPUT}⚠ ${OLD_DRAFTS} of them are older than 7 days — may be outdated.\n"
    fi
  fi
fi

if [ -n "$OUTPUT" ]; then
  echo ""
  echo -e "$OUTPUT"
  echo ""
fi

exit 0
