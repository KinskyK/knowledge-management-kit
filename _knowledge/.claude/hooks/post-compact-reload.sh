#!/bin/bash
# Hook: post-compact-reload
# Fires after context compaction (PostCompact).
# Reads task stack + latest session context from roadmap.md and injects
# back into Claude's context via additionalContext.
# Written in python to avoid echo -e / shell escaping issues with JSON.

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

[ ! -f "meta/roadmap.md" ] && exit 0
SESSIONS=""
[ -f "meta/sessions.md" ] && SESSIONS="meta/sessions.md"

python3 - "meta/roadmap.md" "$SESSIONS" << 'PYTHON'
import sys, json, re

roadmap_path = sys.argv[1]
sessions_path = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None

try:
    with open(roadmap_path, 'r', encoding='utf-8') as f:
        content = f.read()
except Exception:
    # Fallback: can't read roadmap
    print(json.dumps({
        "systemMessage": "⚠️ Контекст НЕ восстановлен после компрессии: не удалось прочитать meta/roadmap.md. Прочитай его вручную."
    }))
    sys.exit(0)

# Extract task stack (between "## Стек задач" and "## Сессионный контекст")
task_stack = ""
match = re.search(r'## Стек задач\n(.*?)(?=## Сессионный контекст)', content, re.DOTALL)
if match:
    task_stack = match.group(1).strip()

# Extract latest session block from sessions.md (if available)
latest_session = ""
if sessions_path:
    try:
        with open(sessions_path, 'r', encoding='utf-8') as f:
            sessions_content = f.read()
        sessions_blocks = re.split(r'(?=^### Сессия )', sessions_content, flags=re.MULTILINE)
        for block in sessions_blocks:
            if block.startswith('### Сессия '):
                latest_session = block.strip()
                break
    except Exception:
        pass

# Build context
parts = []
if task_stack:
    parts.append("## Текущий стек задач (из roadmap.md)\n" + task_stack)
if latest_session:
    parts.append("## Последний сессионный контекст (из sessions.md)\n" + latest_session)

if not parts:
    sys.exit(0)

context = "\n\n".join(parts)

print(json.dumps({
    "systemMessage": "Контекст восстановлен после компрессии. Стек задач из roadmap.md, сессионный блок из sessions.md.",
    "hookSpecificOutput": {
        "hookEventName": "PostCompact",
        "additionalContext": context
    }
}, ensure_ascii=False))
PYTHON
