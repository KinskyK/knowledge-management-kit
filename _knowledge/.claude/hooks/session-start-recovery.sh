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
  OUTPUT="${OUTPUT}⚠️ ПРЕДЫДУЩАЯ СЕССИЯ ЗАВЕРШИЛАСЬ БЕЗ КОММИТА.\n"
  OUTPUT="${OUTPUT}Незакоммиченных файлов: ${COUNT}\n\n"
  OUTPUT="${OUTPUT}$(echo "$CHANGED" | head -15)\n\n"
  OUTPUT="${OUTPUT}Рекомендация: просмотри git diff, обнови roadmap.md / sessions.md, закоммить.\n"
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
        OUTPUT="${OUTPUT}\n📋 roadmap.md последний раз обновлялся ${HOURS_AGO}ч назад.\n"
        OUTPUT="${OUTPUT}Возможно, FAR-аудит не проводился. Рекомендация: запусти /far в начале сессии.\n"
      fi
    fi
  fi
fi

# --- Check 3: Load last session context ---
SESSIONS="meta/sessions.md"
if [ -f "$SESSIONS" ]; then
  LAST_SESSION=$(grep -n "^### Сессия" "$SESSIONS" | head -1 | cut -d: -f1)
  if [ -n "$LAST_SESSION" ]; then
    OUTPUT="${OUTPUT}\n📋 Последний сессионный контекст (sessions.md):\n"
    OUTPUT="${OUTPUT}$(tail -n +$LAST_SESSION "$SESSIONS" | head -20)\n"
  fi
fi

if [ -n "$OUTPUT" ]; then
  echo ""
  echo -e "$OUTPUT"
  echo ""
fi

exit 0
