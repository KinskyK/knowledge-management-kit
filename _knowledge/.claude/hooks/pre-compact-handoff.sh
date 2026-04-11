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
  "systemMessage": "⚠️ КОМПРЕССИЯ КОНТЕКСТА. sessions.md / roadmap.md обновлялись недавно — проверь:\n1. Все ли решения записаны в decisions/?\n2. Все ли исследования сохранены в docs/?\n3. HOT-задачи актуальны в roadmap?\n4. WARM записан в sessions.md?\n5. Есть ли незаписанные решения? → /draft\nПосле проверки — компрессия безопасна."
}
JSON
else
  # WARM NOT saved — CRITICAL
  cat <<'JSON'
{
  "systemMessage": "🚨 CRITICAL: КОМПРЕССИЯ КОНТЕКСТА, но sessions.md / roadmap.md НЕ обновлялись!\nНЕМЕДЛЕННО:\n1. Запиши черновик решений → /draft\n2. Запиши что сейчас в HOT (задача, вопросы) в sessions.md\n3. Запиши WARM-резидуал в meta/sessions.md\n4. Есть ли незаписанные решения → decisions/?\n5. Есть ли несохранённое исследование → docs/?\nТолько после записи компрессия безопасна."
}
JSON
fi
