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
  "systemMessage": "📝 СЕССИЯ ЗАВЕРШАЕТСЯ. Есть незакоммиченные изменения, но нет черновиков.\n\nЗапиши черновик в meta/drafts/ прежде чем контекст потеряется:\n- Какие решения приняты и ПОЧЕМУ?\n- Что рассматривалось и было ОТВЕРГНУТО?\n- Какие проблемы обнаружены?\n- Какие вопросы остались открытыми?\n\nКоманда: /draft"
}
JSON
elif [ "$DRAFT_COUNT" -gt 0 ]; then
  cat <<'JSON'
{
  "systemMessage": "📝 Сессия завершается. Черновики есть (meta/drafts/). Проверь: все ли решения из этой сессии зафиксированы?"
}
JSON
fi

exit 0
