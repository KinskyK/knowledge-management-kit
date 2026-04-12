# Auto-Capture Drafts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure knowledge from sessions is captured before it's lost — through a behavioral protocol for real-time capture plus 4 automated safety nets that check and remind at system events.

**Architecture:** Four layers of increasing reliability: (1) behavioral protocol in CLAUDE.md — "write draft when decision is made" — best quality, least reliable; (2) Stop hook — session ending, last chance to capture; (3) PreCompact hook enhancement — context about to be compressed; (4) pre-commit hook enhancement — checks for missing drafts and validates ADR content. All drafts go to `meta/drafts/`. Secretary protocol processes them at commit time.

**Tech Stack:** Bash (hooks), Markdown (protocol rules, command), JSON (settings.local.json)

---

## File Structure

```
meta/
└── drafts/                          # NEW: buffer for session drafts (gitignored, transient)
    └── .gitkeep                     # Keep the directory in git

.claude/
├── hooks/
│   ├── pre-commit-secretary.sh      # MODIFY: add draft check + ADR content validation
│   ├── pre-compact-handoff.sh       # MODIFY: add draft reminder
│   └── session-end-capture.sh       # NEW: Stop hook — prompt to write draft
├── commands/
│   └── draft.md                     # NEW: /draft command — manual draft writing helper
└── settings.local.json              # MODIFY: add Stop hook

CLAUDE.md                            # MODIFY: add auto-capture protocol + update secretary protocol
```

---

### Task 1: Create meta/drafts/ Directory + .gitignore

**Files:**
- Create: `meta/drafts/.gitkeep`
- Modify: `.gitignore`

- [ ] **Step 1: Create drafts directory with .gitkeep**

```bash
mkdir -p meta/drafts
touch meta/drafts/.gitkeep
```

- [ ] **Step 2: Add drafts content to .gitignore (but keep the directory)**

Read `.gitignore`, then append:

```
# Auto-capture drafts (transient, processed at commit)
meta/drafts/*.md
```

Note: `.gitkeep` is NOT a .md file, so it stays tracked. The directory exists in git, but draft files are ignored.

- [ ] **Step 3: Commit**

```bash
git add meta/drafts/.gitkeep .gitignore
git commit -m "feat(auto-capture): create meta/drafts/ directory for session drafts"
```

---

### Task 2: /draft Command

**Files:**
- Create: `.claude/commands/draft.md`

- [ ] **Step 1: Create the command file**

```markdown
Write a session draft capturing decisions, reasoning, and open questions.

Argument: optional topic focus (e.g. `/draft GraphRAG architecture`). If no argument, capture everything from current session.

## Instructions

### Step 1: Review current session

Look back through the conversation. Identify:

**Decisions made:**
- What was decided?
- WHY was it decided? (the reasoning, not just the outcome)
- What alternatives were considered?
- Why were alternatives rejected?

**Problems found:**
- What broke or didn't work?
- What was the root cause?
- How was it resolved?

**Approach changes:**
- Did we change direction? From what to what?
- Why did we change?

**Open questions:**
- What remains unresolved?
- What needs further investigation?

### Step 2: Write draft

Create a file in `meta/drafts/` with name format: `YYYY-MM-DD-HHMMSS-topic.md`

Use current date/time. Topic: short slug from the main subject.

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

#### Изменённые файлы
- [список файлов с описанием что изменилось]
```

### Step 3: Confirm

Report: "Черновик записан: meta/drafts/[filename]. N решений, M проблем, K открытых вопросов."
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/draft.md
git commit -m "feat(auto-capture): /draft command for manual session draft writing"
```

---

### Task 3: Stop Hook — Session End Capture

**Files:**
- Create: `.claude/hooks/session-end-capture.sh`
- Modify: `.claude/settings.local.json`

- [ ] **Step 1: Create the Stop hook script**

```bash
#!/bin/bash
# Hook: session-end-capture
# Fires at Stop (session ending). Prompts Claude to write a draft
# if there were meaningful exchanges and no draft exists yet.

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

DRAFTS_DIR="meta/drafts"
[ -d "$DRAFTS_DIR" ] || exit 0

# Check if any drafts were written today
TODAY=$(date +%Y-%m-%d)
TODAY_DRAFTS=$(find "$DRAFTS_DIR" -name "${TODAY}*.md" 2>/dev/null | wc -l | tr -d ' ')

# Check if there are uncommitted changes (indicates work was done)
CHANGED=$(git status --porcelain --no-renames 2>/dev/null | grep -v '\.claude/' | grep -v 'meta/drafts/' | wc -l | tr -d ' ')

if [ "$TODAY_DRAFTS" -eq 0 ] && [ "$CHANGED" -gt 0 ]; then
  cat <<'JSON'
{
  "systemMessage": "📝 СЕССИЯ ЗАВЕРШАЕТСЯ. Есть незакоммиченные изменения, но нет черновиков.\n\nЗапиши черновик в meta/drafts/ прежде чем контекст потеряется:\n- Какие решения приняты и ПОЧЕМУ?\n- Что рассматривалось и было ОТВЕРГНУТО?\n- Какие проблемы обнаружены?\n- Какие вопросы остались открытыми?\n\nКоманда: /draft"
}
JSON
elif [ "$TODAY_DRAFTS" -gt 0 ]; then
  cat <<'JSON'
{
  "systemMessage": "📝 Сессия завершается. Черновики за сегодня есть (meta/drafts/). Проверь: все ли решения из этой сессии зафиксированы?"
}
JSON
fi

exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x .claude/hooks/session-end-capture.sh
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n .claude/hooks/session-end-capture.sh && echo "OK"
```
Expected: `OK`

- [ ] **Step 4: Add Stop hook to settings.local.json**

Read `.claude/settings.local.json`. Add a `"Stop"` entry to the `"hooks"` object, after the existing `"SessionStart"` block:

```json
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

- [ ] **Step 5: Verify JSON is valid**

```bash
python3 -c "import json; json.load(open('.claude/settings.local.json')); print('OK')"
```
Expected: `OK`

- [ ] **Step 6: Commit**

```bash
git add .claude/hooks/session-end-capture.sh .claude/settings.local.json
git commit -m "feat(auto-capture): Stop hook — prompts draft writing at session end"
```

---

### Task 4: Enhance PreCompact Hook

**Files:**
- Modify: `.claude/hooks/pre-compact-handoff.sh`

- [ ] **Step 1: Add draft check to pre-compact-handoff.sh**

Read the current file. The script has two branches: "WARM was likely saved" (soft reminder) and "WARM NOT saved" (CRITICAL). In BOTH branches, add a draft reminder.

After the `if [ "$HAS_DIFF" = true ] ...` block (the soft reminder branch), before the closing `fi`, enhance the systemMessage to include draft check.

Replace the soft reminder JSON:

```json
{
  "systemMessage": "⚠️ КОМПРЕССИЯ КОНТЕКСТА. sessions.md / roadmap.md обновлялись недавно — проверь что WARM-резидуал полный:\n1. Все ли решения записаны в decisions/?\n2. Все ли исследования сохранены в docs/?\n3. HOT-задачи актуальны в roadmap?\n4. WARM записан в sessions.md?\n5. Есть ли незаписанные решения? → /draft\nПосле проверки — компрессия безопасна."
}
```

Replace the CRITICAL JSON:

```json
{
  "systemMessage": "🚨 CRITICAL: КОМПРЕССИЯ КОНТЕКСТА, но sessions.md / roadmap.md НЕ обновлялись в этой сессии!\nWARM-резидуал будет ПОТЕРЯН при компрессии.\nНЕМЕДЛЕННО:\n1. Запиши черновик решений в meta/drafts/ → /draft\n2. Запиши WARM-резидуал в meta/sessions.md\n3. Есть ли незаписанные решения → decisions/?\n4. Есть ли несохранённое исследование → docs/?\nТолько после записи компрессия безопасна."
}
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n .claude/hooks/pre-compact-handoff.sh && echo "OK"
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add .claude/hooks/pre-compact-handoff.sh
git commit -m "feat(auto-capture): PreCompact hook — remind about /draft before compression"
```

---

### Task 5: Enhance Pre-Commit Hook — Draft Processing + Content Validation

**Files:**
- Modify: `.claude/hooks/pre-commit-secretary.sh`

- [ ] **Step 1: Add draft detection at the TOP of the checklist output**

After line 66 (`echo ""`) and before the secretary checklist (line 68 `echo "📋 СЕКРЕТАРСКИЙ ПРОТОКОЛ:"`), add:

```bash
# Check for unprocessed drafts
DRAFTS_DIR="meta/drafts"
DRAFT_COUNT=0
if [ -d "$DRAFTS_DIR" ]; then
  DRAFT_COUNT=$(find "$DRAFTS_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$DRAFT_COUNT" -gt 0 ]; then
  echo "📝 ЧЕРНОВИКИ СЕССИЙ: $DRAFT_COUNT файлов в meta/drafts/"
  echo "  Прочитай их и используй как основу для пунктов 1-8."
  echo "  После оформления в ADR/sessions/docs — удали обработанные черновики."
  echo ""
fi
```

- [ ] **Step 2: Add ADR content validation after orphan checks**

After the existing orphan validation block (around line 143, before the sessions.md validation), add:

```bash
# Validate ADR content: check for Отвергнуто section
if [ "$HAS_DECISIONS" = true ]; then
  MISSING_REJECTED=""
  for f in $CHANGED; do
    case "$f" in
      meta/decisions/*/*.md)
        case "$(basename "$f")" in
          _index.md|_tags.md) continue ;;
        esac
        if [ -f "$f" ]; then
          if ! grep -q "Отвергнуто" "$f" 2>/dev/null; then
            MISSING_REJECTED="${MISSING_REJECTED}\n  - $f — нет секции Отвергнуто"
          fi
        fi
        ;;
    esac
  done
  if [ -n "$MISSING_REJECTED" ]; then
    WARNINGS="${WARNINGS}\n⚠ ADR без секции Отвергнуто (рекомендуется):${MISSING_REJECTED}"
  fi
fi

# Check: significant changes but no drafts
if [ "$DRAFT_COUNT" -eq 0 ] && [ "$HAS_DECISIONS" = true ]; then
  WARNINGS="${WARNINGS}\n⚠ Коммитишь решения без черновиков обсуждений. Запиши: /draft"
fi
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n .claude/hooks/pre-commit-secretary.sh && echo "OK"
```
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add .claude/hooks/pre-commit-secretary.sh
git commit -m "feat(auto-capture): pre-commit — draft detection + ADR Отвергнуто validation"
```

---

### Task 6: Update CLAUDE.md — Auto-Capture Protocol

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add auto-capture rule to Knowledge Management section**

After the line about "Секция 'Отвергнуто' в ADR" (line 81) and before "Push-эвристика" (line 82), insert:

```markdown
- **Автозахват черновиков** (meta/drafts/): при принятии решения, обнаружении проблемы или изменении подхода — немедленно запиши черновик в `meta/drafts/` через `/draft`. Не дожидайся коммита. Включай: что решили, ПОЧЕМУ, что отвергли и почему. Это сырьё для секретарского протокола.
```

- [ ] **Step 2: Update secretary protocol — add step 0**

Change the secretary protocol header from:

```
- **Секретарский протокол перед коммитом** (7 пунктов):
```

to:

```
- **Секретарский протокол перед коммитом** (9 пунктов):
  0. Есть черновики в meta/drafts/? → прочитай, используй как основу для пунктов ниже. Оформленные — удали.
```

And renumber the old step 8 (GraphRAG) to step 9.

- [ ] **Step 3: Verify CLAUDE.md is under 200 lines**

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

### Task 7: Update Session-Start Hook — Show Pending Drafts

**Files:**
- Modify: `.claude/hooks/session-start-recovery.sh`

- [ ] **Step 1: Add draft notification to session-start**

After the session context loading block (after the `fi` that closes the `$SESSIONS` check, around line 53), add:

```bash
# --- Check 4: Pending drafts ---
DRAFTS_DIR="meta/drafts"
if [ -d "$DRAFTS_DIR" ]; then
  DRAFT_COUNT=$(find "$DRAFTS_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$DRAFT_COUNT" -gt 0 ]; then
    OUTPUT="${OUTPUT}\n📝 Необработанных черновиков: ${DRAFT_COUNT} в meta/drafts/\n"
    OUTPUT="${OUTPUT}Прочитай и оформи в ADR/sessions при следующем коммите.\n"
    # Show filenames
    OUTPUT="${OUTPUT}$(find "$DRAFTS_DIR" -name "*.md" -exec basename {} \; 2>/dev/null | head -5)\n"
  fi
fi
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n .claude/hooks/session-start-recovery.sh && echo "OK"
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add .claude/hooks/session-start-recovery.sh
git commit -m "feat(auto-capture): session-start shows pending drafts count"
```

---

### Task 8: Update Architecture Map

**Files:**
- Modify: `docs/architecture-map.md`

- [ ] **Step 1: Add auto-capture section**

Find the section about the secretary protocol in architecture-map.md (the "Проблема пятая: дисциплина" section). After the description of `pre-commit-secretary` hook, add a new subsection:

```markdown

### Автозахват черновиков — мост между работой и записью

Протоколы работают, но зависят от дисциплины Claude. В конце длинной сессии Claude может не помнить, что обсуждалось в начале. Секретарский протокол при коммите спрашивает "есть ли незаписанные решения?" — но к тому моменту детали обсуждения (почему решили, что отвергли) уже размыты.

Автозахват решает это через два механизма:

**Поведенческий протокол** — при принятии решения, обнаружении проблемы или изменении подхода Claude сразу записывает черновик в `meta/drafts/`. Не полированный ADR, а сырой материал: что решили, почему, что отвергли, какие аргументы перевесили. Это самый качественный захват — пока контекст свежий.

**Четыре страховочных сетки:**
- **Stop hook** — сессия заканчивается: "есть незакоммиченные изменения но нет черновиков — запиши сейчас"
- **PreCompact hook** — контекст вот-вот сожмётся: "запиши черновик прежде чем потеряешь контекст"
- **Pre-commit hook** — перед коммитом: "есть черновики? прочитай и оформи. Нет черновиков? запиши"
- **Session-start hook** — в начале новой сессии: "есть необработанные черновики с прошлого раза"

Разделение ответственности: автозахват фиксирует сырьё (решения + рассуждения + альтернативы), секретарский протокол оформляет его (ADR, sessions.md, индексы). Один — про память, другой — про качество.

Это дополняет FAR: FAR управляет вниманием (что держать в голове), автозахват управляет знаниями (что записать на бумагу). FAR может выкинуть ход обсуждения как COLD — но автозахват перед этим сохранил его в черновик.
```

- [ ] **Step 2: Commit**

```bash
git add docs/architecture-map.md
git commit -m "docs: auto-capture section in architecture map"
```

---

## Summary

| Task | What | Safety Net Layer |
|------|------|------------------|
| 1 | Create meta/drafts/ directory | Infrastructure |
| 2 | /draft command | Behavioral (manual trigger) |
| 3 | Stop hook | Safety net 1: session end |
| 4 | Enhanced PreCompact hook | Safety net 2: before compression |
| 5 | Enhanced pre-commit hook | Safety net 3: before commit + content validation |
| 6 | CLAUDE.md protocol update | Behavioral (automatic trigger) |
| 7 | Session-start draft notification | Safety net 4: next session reminder |
| 8 | Architecture map update | Documentation |

**Total: 8 tasks, 8 commits.**

**Coverage of the 4-layer safety net:**

| Layer | Mechanism | Reliability | Quality |
|-------|-----------|-------------|---------|
| Behavioral protocol (CLAUDE.md) | Claude writes draft at decision time | Low — can forget | High — full context |
| Stop hook | systemMessage at session end | High — always fires | Medium — may forget details |
| PreCompact hook | systemMessage before compression | High — always fires | Medium — context about to be lost |
| Pre-commit hook | Check for drafts + validate ADR content | High — always fires | N/A — checks, doesn't write |
| Session-start hook | Show pending drafts from last session | High — always fires | N/A — reminder only |

**What this does NOT do:**
- Does not automatically extract knowledge (requires Claude's intelligence)
- Does not guarantee Claude will write high-quality drafts (behavioral)
- Does not replace the secretary protocol (drafts are raw material, not finished ADR)

**What this DOES do:**
- Makes it hard to lose knowledge — at least 3 opportunities to capture before it's gone
- Validates ADR quality — checks for missing "Отвергнуто" section
- Shows unprocessed drafts — so they don't accumulate forgotten
