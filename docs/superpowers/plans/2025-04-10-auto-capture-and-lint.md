# Auto-Capture Drafts + Extended Lint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** (1) Capture knowledge before it's lost — behavioral protocol + 4 automated safety nets. (2) Extend lint-refs with staleness and orphan detection.

**Architecture:** Drafts go to `meta/drafts/`. Behavioral protocol: Claude writes quick notes at decision time. Safety nets: Stop hook, PreCompact enhancement, pre-commit enhancement, session-start notification. Secretary protocol gets step 0: "read drafts first." Lint gets 2 new checks: stale review triggers and orphan files (no incoming/outgoing references).

**Tech Stack:** Bash (hooks, lint), Markdown (protocol, commands), JSON (settings.local.json)

**Audit fixes applied from v1 audit:**
- Numbering: secretary protocol becomes "пункты 0-8" (9 points), step 0 added, old 1-8 unchanged
- PreCompact CRITICAL branch: keeps "запиши HOT" alongside "запиши черновик"
- Stop hook: checks ANY existing drafts, not just today's (avoids midnight edge case)
- Pre-commit checklist in hook updated with step 0
- Comma after SessionStart in JSON noted explicitly
- `-maxdepth 1` added to find commands
- Stop hook documented as best-effort (may not fire on forced close)
- Task code shows exact text replacements, not line numbers

---

## File Structure

```
meta/
└── drafts/                          # NEW: buffer for session drafts
    └── .gitkeep                     # Keeps directory in git

.claude/
├── hooks/
│   ├── pre-commit-secretary.sh      # MODIFY: draft check + step 0 in checklist + ADR Отвергнуто validation
│   ├── pre-compact-handoff.sh       # MODIFY: add draft reminder to both branches
│   ├── session-start-recovery.sh    # MODIFY: show pending drafts + stale draft warning
│   ├── session-end-capture.sh       # NEW: Stop hook
│   └── lint-refs.sh                 # MODIFY: add staleness + orphan checks
├── commands/
│   └── draft.md                     # NEW: /draft command
└── settings.local.json              # MODIFY: add Stop hook

CLAUDE.md                            # MODIFY: auto-capture protocol + secretary step 0
docs/architecture-map.md             # MODIFY: add auto-capture section
```

---

### Task 1: Create meta/drafts/ + .gitignore

**Files:**
- Create: `meta/drafts/.gitkeep`
- Modify: `.gitignore`

- [ ] **Step 1: Create directory**

```bash
mkdir -p meta/drafts && touch meta/drafts/.gitkeep
```

- [ ] **Step 2: Add to .gitignore**

Append to `.gitignore`:

```
# Auto-capture drafts (transient, processed at commit)
meta/drafts/*.md
```

- [ ] **Step 3: Commit**

```bash
git add meta/drafts/.gitkeep .gitignore
git commit -m "feat(auto-capture): create meta/drafts/ for session drafts"
```

---

### Task 2: /draft Command

**Files:**
- Create: `.claude/commands/draft.md`

- [ ] **Step 1: Create command file**

```markdown
Write a session draft capturing decisions, reasoning, and open questions.

Argument: optional topic (e.g. `/draft GraphRAG architecture`). No argument = capture everything from current session.

## Instructions

### Step 1: Review session

Look through the conversation. Identify:

- **Decisions:** What decided? WHY? What alternatives considered? Why rejected?
- **Problems:** What broke? Root cause? Resolution?
- **Approach changes:** Changed direction? From what to what? Why?
- **Open questions:** What unresolved? What needs investigation?

### Step 2: Write draft

Create file: `meta/drafts/YYYY-MM-DD-HHMMSS-topic.md`

Format:

```
### Черновик: [тема]
Дата: YYYY-MM-DD HH:MM

#### Решения
- **[Что решили]**: [почему]. Отвергнуто: [что и почему].

#### Проблемы
- **[Проблема]**: [причина] → [решение]

#### Изменения подхода
- **Было:** [старый подход]. **Стало:** [новый]. **Почему:** [причина]

#### Открытые вопросы
- [вопрос]
```

### Step 3: Confirm

Report: "Черновик записан: meta/drafts/[filename]. N решений, M проблем, K вопросов."
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/draft.md
git commit -m "feat(auto-capture): /draft command for session draft writing"
```

---

### Task 3: Stop Hook

**Files:**
- Create: `.claude/hooks/session-end-capture.sh`
- Modify: `.claude/settings.local.json`

- [ ] **Step 1: Create hook script**

```bash
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
```

- [ ] **Step 2: Make executable and verify syntax**

```bash
chmod +x .claude/hooks/session-end-capture.sh
bash -n .claude/hooks/session-end-capture.sh && echo "OK"
```

- [ ] **Step 3: Add Stop hook to settings.local.json**

In `.claude/settings.local.json`, find the closing `]` of the `"SessionStart"` block. Add a comma after it, then add the Stop block. The result should look like:

```json
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-start-recovery.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-end-capture.sh",
            "timeout": 10
          }
        ]
      }
    ]
```

Note: the comma after `SessionStart`'s closing `]` is critical — without it JSON is invalid.

- [ ] **Step 4: Validate JSON**

```bash
python3 -c "import json; json.load(open('.claude/settings.local.json')); print('JSON OK')"
```

- [ ] **Step 5: Commit**

```bash
git add .claude/hooks/session-end-capture.sh .claude/settings.local.json
git commit -m "feat(auto-capture): Stop hook — prompt draft at session end"
```

---

### Task 4: Enhance PreCompact Hook

**Files:**
- Modify: `.claude/hooks/pre-compact-handoff.sh`

- [ ] **Step 1: Update soft reminder (WARM was saved)**

Find the existing soft reminder JSON block (starts with `"systemMessage": "⚠️ КОМПРЕССИЯ КОНТЕКСТА. sessions.md`). Replace it with:

```json
{
  "systemMessage": "⚠️ КОМПРЕССИЯ КОНТЕКСТА. sessions.md / roadmap.md обновлялись недавно — проверь:\n1. Все ли решения записаны в decisions/?\n2. Все ли исследования сохранены в docs/?\n3. HOT-задачи актуальны в roadmap?\n4. WARM записан в sessions.md?\n5. Есть ли незаписанные решения? → /draft\nПосле проверки — компрессия безопасна."
}
```

- [ ] **Step 2: Update CRITICAL reminder (WARM not saved)**

Find the existing CRITICAL JSON block (starts with `"systemMessage": "🚨 CRITICAL`). Replace it with:

```json
{
  "systemMessage": "🚨 CRITICAL: КОМПРЕССИЯ КОНТЕКСТА, но sessions.md / roadmap.md НЕ обновлялись!\nНЕМЕДЛЕННО:\n1. Запиши черновик решений → /draft\n2. Запиши что сейчас в HOT (задача, вопросы) в sessions.md\n3. Запиши WARM-резидуал в meta/sessions.md\n4. Есть ли незаписанные решения → decisions/?\n5. Есть ли несохранённое исследование → docs/?\nТолько после записи компрессия безопасна."
}
```

Note: step 2 preserves the original "запиши HOT" which was lost in v1 plan. Draft writing (step 1) is added alongside, not instead of.

- [ ] **Step 3: Verify syntax**

```bash
bash -n .claude/hooks/pre-compact-handoff.sh && echo "OK"
```

- [ ] **Step 4: Commit**

```bash
git add .claude/hooks/pre-compact-handoff.sh
git commit -m "feat(auto-capture): PreCompact hook — /draft reminder in both branches"
```

---

### Task 5: Enhance Pre-Commit Hook

**Files:**
- Modify: `.claude/hooks/pre-commit-secretary.sh`

- [ ] **Step 1: Add draft notification before checklist**

Find the line `echo "📋 СЕКРЕТАРСКИЙ ПРОТОКОЛ:"`. Insert BEFORE it:

```bash
# Check for unprocessed drafts
DRAFTS_DIR="meta/drafts"
DRAFT_COUNT=0
if [ -d "$DRAFTS_DIR" ]; then
  DRAFT_COUNT=$(find "$DRAFTS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$DRAFT_COUNT" -gt 0 ]; then
  echo "📝 ЧЕРНОВИКИ: $DRAFT_COUNT файлов в meta/drafts/"
  echo "  Прочитай и используй как основу для пунктов ниже."
  echo "  После оформления в ADR/sessions — удали обработанные."
  echo ""
fi
```

- [ ] **Step 2: Add step 0 to checklist**

Find `echo "  1. Провёл ли FAR-аудит?"`. Insert BEFORE it:

```bash
echo "  0. Черновики в meta/drafts/ → прочитай, оформи, удали обработанные"
```

- [ ] **Step 3: Add ADR Отвергнуто validation**

Find the line `if [ -n "$WARNINGS" ]; then` (the final warnings output block). Insert BEFORE it:

```bash
# Validate ADR content: check for Отвергнуто section in changed files
if [ "$HAS_DECISIONS" = true ]; then
  MISSING_REJECTED=""
  for f in $CHANGED; do
    case "$f" in
      meta/decisions/*/*.md)
        bn=$(basename "$f")
        case "$bn" in _index.md|_tags.md) continue ;; esac
        if [ -f "$f" ] && ! grep -q "Отвергнуто" "$f" 2>/dev/null; then
          MISSING_REJECTED="${MISSING_REJECTED}\n  - $f"
        fi
        ;;
    esac
  done
  if [ -n "$MISSING_REJECTED" ]; then
    WARNINGS="${WARNINGS}\n⚠ ADR без секции Отвергнуто (рекомендуется при редактировании):${MISSING_REJECTED}"
  fi
fi

# Warn if committing decisions but no drafts exist
if [ "$DRAFT_COUNT" -eq 0 ] && [ "$HAS_DECISIONS" = true ]; then
  WARNINGS="${WARNINGS}\n⚠ Коммитишь решения без черновиков обсуждений. Запиши: /draft"
fi
```

- [ ] **Step 4: Verify syntax**

```bash
bash -n .claude/hooks/pre-commit-secretary.sh && echo "OK"
```

- [ ] **Step 5: Commit**

```bash
git add .claude/hooks/pre-commit-secretary.sh
git commit -m "feat(auto-capture): pre-commit — step 0, draft check, Отвергнуто validation"
```

---

### Task 6: Enhance Session-Start Hook

**Files:**
- Modify: `.claude/hooks/session-start-recovery.sh`

- [ ] **Step 1: Add draft notification**

Find `if [ -n "$OUTPUT" ]; then`. Insert BEFORE it:

```bash
# --- Check 4: Pending drafts ---
DRAFTS_DIR="meta/drafts"
if [ -d "$DRAFTS_DIR" ]; then
  DRAFT_COUNT=$(find "$DRAFTS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$DRAFT_COUNT" -gt 0 ]; then
    OUTPUT="${OUTPUT}\n📝 Необработанных черновиков: ${DRAFT_COUNT} в meta/drafts/\n"
    OUTPUT="${OUTPUT}Оформи в ADR/sessions при следующем коммите.\n"

    # Warn if drafts are older than 7 days
    OLD_DRAFTS=$(find "$DRAFTS_DIR" -maxdepth 1 -name "*.md" -mtime +7 2>/dev/null | wc -l | tr -d ' ')
    if [ "$OLD_DRAFTS" -gt 0 ]; then
      OUTPUT="${OUTPUT}⚠ Из них ${OLD_DRAFTS} старше 7 дней — возможно, уже неактуальны.\n"
    fi
  fi
fi
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n .claude/hooks/session-start-recovery.sh && echo "OK"
```

- [ ] **Step 3: Commit**

```bash
git add .claude/hooks/session-start-recovery.sh
git commit -m "feat(auto-capture): session-start shows pending + stale drafts"
```

---

### Task 7: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add auto-capture rule**

Find the line starting with `- **Секция "Отвергнуто" в ADR**:`. Insert AFTER it:

```markdown
- **Автозахват черновиков** (meta/drafts/): при принятии решения, обнаружении проблемы или изменении подхода — запиши черновик через `/draft`. Не дожидайся коммита. Включай: что решили, ПОЧЕМУ, что отвергли. Это сырьё для секретарского протокола.
```

- [ ] **Step 2: Update secretary protocol**

Find `- **Секретарский протокол перед коммитом** (7 пунктов):`. Replace with:

```markdown
- **Секретарский протокол перед коммитом** (пункты 0-8):
  0. Есть черновики в meta/drafts/? → прочитай, оформи решения в ADR + инсайты в sessions.md, удали обработанные
```

Do NOT renumber old points 1-7. They stay as is. Only old point 8 (GraphRAG) becomes 8 — no change needed since it was already 8. Full sequence: 0,1,2,3,4,5,6,7,8 (9 points).

- [ ] **Step 3: Verify line count**

```bash
wc -l CLAUDE.md
```
Expected: < 200

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "feat(auto-capture): CLAUDE.md — auto-capture protocol + secretary step 0"
```

---

### Task 8: Extended Lint — Staleness + Orphans

**Files:**
- Modify: `.claude/hooks/lint-refs.sh`

- [ ] **Step 1: Add staleness check**

Find the line `echo "═══════════════════════════════"` (the final summary separator). Insert BEFORE it:

```bash
# ═══════════════════════════════════════════
# F. Устаревшие триггеры пересмотра
# ═══════════════════════════════════════════
echo "F. Устаревшие триггеры пересмотра"

HUB="meta/decisions/_index.md"
if [ -f "$HUB" ]; then
  while IFS= read -r line; do
    # Extract CODE from ⚠ lines
    CODE=$(echo "$line" | grep -oE '[A-Z][A-Za-z0-9_-]*-[0-9]+' | head -1)
    if [ -n "$CODE" ]; then
      # Find the ADR file
      ADR_FILE=$(find meta/decisions -name "${CODE}.md" 2>/dev/null | head -1)
      if [ -n "$ADR_FILE" ] && [ -f "$ADR_FILE" ]; then
        # Check last modification (git)
        LAST_MOD=$(git log -1 --format="%ci" -- "$ADR_FILE" 2>/dev/null | cut -d' ' -f1)
        if [ -n "$LAST_MOD" ]; then
          DAYS_AGO=$(( ($(date +%s) - $(date -j -f "%Y-%m-%d" "$LAST_MOD" +%s 2>/dev/null || date -d "$LAST_MOD" +%s 2>/dev/null || echo 0)) / 86400 ))
          if [ "$DAYS_AGO" -gt 30 ]; then
            warn "$CODE: триггер ⚠ в hub, но файл не обновлялся ${DAYS_AGO} дней"
          fi
        fi
      fi
    fi
  done < <(grep "⚠" "$HUB" 2>/dev/null)
fi

echo ""

# ═══════════════════════════════════════════
# G. Сиротские ADR (нет входящих/исходящих ссылок)
# ═══════════════════════════════════════════
# NOTE: O(n^2) — acceptable for <100 ADR files. For larger projects, consider caching refs.
echo "G. Сиротские ADR (нет ссылок)"

for f in meta/decisions/*/*.md; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  case "$bn" in _index.md|_tags.md) continue ;; esac

  CODE=$(head -1 "$f" | sed 's/^# \([^ ]*\).*/\1/')
  [ -z "$CODE" ] && continue

  # Skip drafts
  grep -q "Статус.*draft" "$f" 2>/dev/null && continue

  # Check if this CODE is referenced by any OTHER ADR file
  HAS_INCOMING=false
  for other in meta/decisions/*/*.md; do
    [ "$other" = "$f" ] && continue
    [ -f "$other" ] || continue
    case "$(basename "$other")" in _index.md|_tags.md) continue ;; esac
    if grep -q "\[\[$CODE\]\]" "$other" 2>/dev/null; then
      HAS_INCOMING=true
      break
    fi
  done

  # Check if this file references any other CODE
  HAS_OUTGOING=false
  if grep -q '\[\[[A-Z]' "$f" 2>/dev/null; then
    HAS_OUTGOING=true
  fi

  if [ "$HAS_INCOMING" = false ] && [ "$HAS_OUTGOING" = false ]; then
    warn "$CODE ($f): нет ни входящих, ни исходящих ссылок [[CODE]]"
  fi
done

echo ""
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n .claude/hooks/lint-refs.sh && echo "OK"
```

- [ ] **Step 3: Test run**

```bash
CLAUDE_PROJECT_DIR="$(pwd)" bash .claude/hooks/lint-refs.sh
```
Expected: sections A-G all shown, no errors (warnings about unused tags are expected since there are no ADR files yet).

- [ ] **Step 4: Commit**

```bash
git add .claude/hooks/lint-refs.sh
git commit -m "feat(lint): staleness check for review triggers + orphan ADR detection"
```

---

### Task 9: Update Architecture Map

**Files:**
- Modify: `docs/architecture-map.md`

- [ ] **Step 1: Add auto-capture section**

Find the line `` > Файлы: `.claude/hooks/` (6 скриптов) `` in the "Проблема пятая: дисциплина" section. Change `(6 скриптов)` to `(7 скриптов)`. Then insert AFTER that line (before the `---` separator):

```markdown

### Автозахват черновиков — мост между работой и записью

Протоколы работают, но зависят от дисциплины Claude. В конце длинной сессии Claude может не помнить, что обсуждалось в начале. Секретарский протокол спрашивает "есть ли незаписанные решения?" — но к тому моменту детали (почему решили, что отвергли) уже размыты.

Автозахват — поведенческий протокол: при принятии решения Claude сразу записывает черновик в `meta/drafts/`. Не полированный ADR, а сырой материал: что решили, почему, что отвергли. Команда `/draft`.

Четыре страховочных сетки на случай если Claude забудет:
- **Stop hook** — сессия заканчивается: "запиши черновик если были обсуждения"
- **PreCompact hook** — контекст сжимается: "запиши прежде чем потеряешь"
- **Pre-commit hook** — перед коммитом: "есть черновики? оформи. Нет? запиши"
- **Session-start hook** — новая сессия: "есть необработанные черновики"

Автозахват и секретарский протокол — разные роли. Автозахват фиксирует сырьё (решения + рассуждения). Секретарский протокол оформляет (ADR, sessions, индексы). Автозахват дополняет FAR: FAR управляет вниманием (что держать в голове), автозахват сохраняет знания (что записать на бумагу).
```

- [ ] **Step 2: Commit**

```bash
git add docs/architecture-map.md
git commit -m "docs: auto-capture + extended lint in architecture map"
```

---

## Summary

| Task | What | Type |
|------|------|------|
| 1 | meta/drafts/ directory + .gitignore | Infrastructure |
| 2 | /draft command | Command |
| 3 | Stop hook + settings.local.json | Hook |
| 4 | PreCompact hook enhancement | Hook |
| 5 | Pre-commit hook: step 0 + Отвергнуто validation + draft check | Hook |
| 6 | Session-start hook: draft notification + stale warning | Hook |
| 7 | CLAUDE.md: auto-capture protocol + secretary step 0 | Protocol |
| 8 | lint-refs.sh: staleness + orphan checks | Lint |
| 9 | Architecture map update | Documentation |

**Total: 9 tasks, 9 commits.**

**Audit fixes from v1 incorporated:**
- ✅ Numbering: "пункты 0-9" not "9 пунктов"
- ✅ PreCompact CRITICAL: keeps "запиши HOT" alongside "запиши черновик"  
- ✅ Stop hook: checks ANY drafts, not just today's
- ✅ Comma after SessionStart in JSON noted explicitly
- ✅ `-maxdepth 1` in all find commands
- ✅ Stop hook documented as best-effort
- ✅ Pre-commit checklist includes step 0
- ✅ Exact text anchors for insertions, not line numbers
- ✅ Stale drafts warning (>7 days) in session-start

**Audit v2 fixes applied:**
- ✅ C1: `\w` → `[A-Za-z0-9_-]` in grep for macOS compatibility
- ✅ C2: pre-commit insertion point clarified ("before `if [ -n "$WARNINGS" ]`")
- ✅ I2: (superseded by v3 fix — see below)
- ✅ I3: O(n^2) comment added to orphan check
- ✅ I6: architecture-map anchor fixed to actual text + update "6 скриптов"→"7 скриптов"

**Audit v3 fixes applied:**
- ✅ Numbering: don't renumber old 1-8, just add step 0. Sequence 0-8 (9 points)
- ✅ Architecture-map anchor: added backticks around `.claude/hooks/`
- ✅ Session-start insertion: "before `if [ -n "$OUTPUT" ]`" instead of ambiguous "before last fi"
