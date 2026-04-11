# Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a distributable `_knowledge/` template folder + install.sh so anyone can install the Knowledge Management Kit with one prompt.

**Architecture:** The `_knowledge/` folder contains parameterized templates of all system files. `install.sh` downloads this folder from GitHub. `INTEGRATION.md` inside it guides Claude through an interview (project name, description, domains) and generates project-specific files. After integration, `_knowledge/` is deleted. Separate `update.sh` handles version updates without losing user data.

**Tech Stack:** Bash (install.sh), Markdown (INTEGRATION.md, templates)

**Audit fixes applied:**
- ✅ Verification BEFORE deletion (steps 5→6 reordered)
- ✅ Full CLAUDE.md.template text in plan (not left to implementer)
- ✅ CLAUDE.md brief updated: session-end-capture hook mentioned
- ✅ INTEGRATION.md: checks for existing meta/ and .claude/hooks/ before overwriting
- ✅ install.sh: git clone wrapped in if (no crash on failure)

---

## File Structure

```
_knowledge/                              # Distributable template folder
├── INTEGRATION.md                       # Claude reads this to run the installation
├── CLAUDE.md.template                   # Parameterized CLAUDE.md ({{PROJECT_NAME}}, etc.)
├── Full Attention Residuals.md          # As-is (universal, no parameters)
├── agents/
│   └── AGENT_PROTOCOL.md               # As-is (universal)
├── meta/
│   ├── roadmap.md                       # Empty template
│   ├── sessions.md                      # Template with format instructions
│   ├── _tags.md                         # Empty template with instructions
│   ├── project_manifest.md              # Empty template
│   ├── drafts/
│   │   └── .gitkeep                     # Buffer for auto-capture
│   ├── decisions/
│   │   └── _index.md                    # Empty hub template
│   └── docs/
│       └── _index.md                    # Empty hub template
├── .claude/
│   ├── hooks/                           # All 7 hooks (as-is)
│   ├── commands/                        # All 7 commands (as-is)
│   ├── scripts/
│   │   └── context.py                   # As-is
│   └── settings.local.json.template     # Parameterized settings
└── templates/
    └── extraction-template.json         # GraphRAG extraction template

install.sh                               # Downloads _knowledge/ from GitHub
README.md                               # MODIFY: update installation section
```

**Key decisions:**
- Files marked "as-is" are copied without changes — they're universal
- Files marked "template" or "parameterized" contain placeholders that Claude fills during INTEGRATION.md
- The `.claude/settings.local.json.template` is a template — Claude merges it with existing settings if present
- `graphrag_mcp/` is NOT included — installed separately via `/graphrag init`

---

### Task 1: INTEGRATION.md — The Installation Script for Claude

**Files:**
- Create: `_knowledge/INTEGRATION.md`

This is the most important file — it's the instruction manual that Claude follows to install the kit.

- [ ] **Step 1: Create INTEGRATION.md**

```markdown
# Integration — Knowledge Management Kit

> Этот файл читает Claude при установке. Пользователь даёт промпт:
> "Прочитай _knowledge/INTEGRATION.md и выполни интеграцию. Веди меня по шагам."

## Шаг 1: Интервью

Спроси у пользователя (по одному вопросу за раз):

1. **Название проекта** — как называется проект? (пример: "my-web-app", "trading-bot")
2. **Описание** — одно предложение: что делает проект? (пример: "Веб-приложение для управления задачами")
3. **Фаза** — на какой стадии? (пример: "прототип", "разработка", "production")
4. **Домены решений** — какие основные области? (пример: "backend, frontend" или "core, api, database"). Минимум 1 домен. Claude может предложить домены на основе описания.
5. **Домены исследований** — какие темы для ресёрча? (пример: "architecture, performance" или ""). Можно пропустить.

## Шаг 2: Проверка существующего CLAUDE.md

Проверь: есть ли уже CLAUDE.md в корне проекта?

**Если есть:**
- Прочитай его
- Сохрани существующее содержимое
- В Шаге 3 объедини: добавь секцию "Модель проекта" из шаблона, сохрани существующие правила пользователя
- Спроси пользователя: "У тебя уже есть CLAUDE.md. Я объединю его с системой управления знаниями. Ок?"

**Если нет:**
- Создадим с нуля из шаблона

## Шаг 3: Генерация файлов

Используй ответы из интервью для заполнения шаблонов.

### 3.1 CLAUDE.md

Прочитай `_knowledge/CLAUDE.md.template`. Замени:
- `{{PROJECT_NAME}}` → название проекта
- `{{PROJECT_DESCRIPTION}}` → описание
- `{{PROJECT_PHASE}}` → фаза
- `{{DECISION_DOMAINS}}` → описание доменов (перечисление)

Если CLAUDE.md уже существует:
- Вставь секцию "## Модель проекта" из шаблона в начало
- Вставь секции "## Инициализация", "## Правила", "## Knowledge Management", "## FAR-протокол" после
- Сохрани все существующие секции пользователя, которых нет в шаблоне

Записать файл: `CLAUDE.md` (в корень проекта)

### 3.2 Структура meta/

Создай директории:
```bash
mkdir -p meta/decisions meta/docs meta/drafts
```

Для каждого домена решений из интервью:
```bash
mkdir -p meta/decisions/{{domain_name}}
```

Для каждого домена исследований (если указаны):
```bash
mkdir -p meta/docs/{{topic_name}}
```

### 3.3 Проверка конфликтов

Перед копированием проверь:

**Если `meta/` уже существует:** спроси пользователя "Директория meta/ уже есть. Можно использовать её для системы управления знаниями? (да/нет)". Если нет — предложить альтернативное имя.

**Если `.claude/hooks/` уже содержит файлы:** покажи список существующих файлов. Спроси "Перезаписать существующие хуки? (да/нет)". Если нет — пропустить копирование хуков и показать инструкцию для ручной интеграции.

### 3.4 Копирование файлов без изменений

Скопируй из `_knowledge/` в корень проекта:
- `Full Attention Residuals.md` → корень
- `agents/AGENT_PROTOCOL.md` → `agents/`
- `meta/roadmap.md` → `meta/`
- `meta/sessions.md` → `meta/`
- `meta/project_manifest.md` → `meta/`
- `meta/drafts/.gitkeep` → `meta/drafts/`
- `.claude/hooks/*` → `.claude/hooks/` (все 7 хуков)
- `.claude/commands/*` → `.claude/commands/` (все 7 команд)
- `.claude/scripts/context.py` → `.claude/scripts/`
- `templates/extraction-template.json` → `templates/`

### 3.4 Генерация индексов

**meta/_tags.md** — создай с доменами из интервью:
```markdown
# Словарь хештегов

Общий для meta/decisions/ и meta/docs/. Новый тег → сначала добавь сюда + обоснуй.

## Система
(пока пусто — теги появятся с первыми решениями)
```

**meta/decisions/_index.md** — hub с доменами из интервью:
```markdown
# Decisions Hub
Решений: 0 | ■ 0 | ◆ 0 | ● 0
Доменные индексы: meta/decisions/{domain}/_index.md

Легенда: ■ АКСИОМА | ◆ ПРАВИЛО | ● ГИПОТЕЗА

## Домены
| Домен | Решений | Статистика | Описание |
|-------|---------|------------|----------|
| {{domain1}} | 0 | ■ 0 ◆ 0 ● 0 | {{описание1}} |
| {{domain2}} | 0 | ■ 0 ◆ 0 ● 0 | {{описание2}} |

## ⚠ Триггеры пересмотра
(пока пусто)
```

Для каждого домена — **meta/decisions/{{domain}}/_index.md**:
```markdown
# {{domain}}
Решений: 0 | ■ 0 | ◆ 0 | ● 0
```

**meta/docs/_index.md** — hub:
```markdown
# Карта исследований

Правило: перед ответом на вопрос по теме — прочитай файл. Не отвечай по памяти.
Доменные индексы: meta/docs/{topic}/_index.md

## Темы
| Тема | Документов | Описание |
|------|------------|----------|
```

Для каждого домена исследований — **meta/docs/{{topic}}/_index.md**:
```markdown
# Документация: {{topic}}
Документов: 0
```

### 3.5 Настройка хуков (.claude/settings.local.json)

Прочитай `_knowledge/.claude/settings.local.json.template`.

**Если `.claude/settings.local.json` уже существует:**
- Прочитай его
- Объедини: добавь хуки из шаблона в существующий блок "hooks". Не затирай существующие хуки пользователя.
- Если хук с тем же событием уже есть — добавь наш в массив hooks, не заменяй.

**Если не существует:**
- Скопируй шаблон как есть, убрав ".template" из имени.

### 3.6 .gitignore

Добавь в `.gitignore` (создай если нет):
```
.claude/settings.local.json
.graphrag/data/
.graphrag/config.yaml
meta/drafts/*.md
```

## Шаг 4: Обновление манифеста

Заполни `meta/project_manifest.md` актуальной структурой файлов проекта.

## Шаг 5: Проверка

Проверь что все файлы созданы ПЕРЕД удалением _knowledge/. Если что-то отсутствует — сообщи пользователю и НЕ удаляй _knowledge/.

Выведи краткий итог:
```
✓ CLAUDE.md — модель проекта + правила
✓ meta/decisions/ — {{N}} доменов
✓ meta/docs/ — {{M}} тем
✓ meta/roadmap.md — стек задач
✓ meta/sessions.md — сессионный контекст
✓ meta/drafts/ — буфер автозахвата
✓ .claude/hooks/ — 7 хуков
✓ .claude/commands/ — 7 команд
✓ Full Attention Residuals.md — спецификация FAR
✓ agents/AGENT_PROTOCOL.md — протокол агента

Если всё ✓ — переходи к Шагу 6.
Если что-то ✗ — сообщи пользователю, НЕ удаляй _knowledge/, попробуй исправить.
```

## Шаг 6: Удаление _knowledge/

Только после успешной проверки в Шаге 5:

```bash
rm -rf _knowledge/
```

Скажи пользователю: "Папка _knowledge/ удалена. Система установлена."

```
Следующие шаги:
- Начни работу. Система активна.
- При первом коммите сработает секретарский протокол.
- Для семантического поиска (опционально): /graphrag init
```

## Шаг 7: GraphRAG (опционально)

Спроси: "Хочешь подключить GraphRAG — семантический поиск + граф знаний? (да/нет)"

Если да → "Запусти `/graphrag init` — он проведёт через настройку."
Если нет → "Можешь подключить позже командой `/graphrag init`."
```

- [ ] **Step 2: Commit**

```bash
git add _knowledge/INTEGRATION.md
git commit -m "feat(installer): INTEGRATION.md — Claude-guided installation script"
```

---

### Task 2: CLAUDE.md Template

**Files:**
- Create: `_knowledge/CLAUDE.md.template`

- [ ] **Step 1: Create parameterized template**

Create `_knowledge/CLAUDE.md.template` with the following EXACT content. This template has two parts: (1) brief section with placeholders for user's project, (2) universal sections (unchanged for all projects).

The brief describes THE USER'S PROJECT. The universal sections describe THE KM SYSTEM (protocols, rules, FAR).

```markdown
# CLAUDE.md — {{PROJECT_NAME}}

## Модель проекта
<!-- brief:
Принципы написания:
1. Это ориентировка для нового агента. После прочтения он должен понимать: что за проект, какие ключевые концепции, какие ограничения, что сейчас в фокусе.
2. Не дублировать то, что есть в roadmap или decisions. Brief = "что это и как думать", не "что делать".
3. Структура: суть → ключевые концепции → текущее состояние → ограничения.
4. Каждый абзац отвечает на вопрос, который возникнет у нового агента.
5. Обновлять перезаписью секции, не добавлением строк. Если секция растёт — что-то лишнее.
6. Бюджет: до 120 содержательных строк. Больше — вынести в отдельный файл.
7. Приоритет: то, что непосредственно меняет поведение агента > то, что объясняет контекст.
   Только текущее состояние, не история. Если не влияет на действия — не включай.
8. Стиль: плотный, без вводных фраз. Каждое предложение несёт информацию.
-->

{{PROJECT_DESCRIPTION}}

**Фаза:** {{PROJECT_PHASE}}

**Ограничения:**
- Git — единственная система версий. Нет _archive/.
- CLAUDE.md не должен превышать 200 строк. Если растёт — выносить.

> Brief = ориентировка. Для работы с конкретной механикой — `/context CODE`.
```

Everything from "## Инициализация" onward is copied as-is from the current CLAUDE.md (lines 38-101). These sections are universal — they describe the KM system, not the project.

IMPORTANT: The brief section (between `<!-- brief: ... -->` and `> Brief = ориентировка`) is what Claude fills based on the interview. `{{PROJECT_DESCRIPTION}}` is replaced with a brief Claude writes ABOUT THE USER'S PROJECT — not a raw copy of the user's answer, but a proper brief following the 8 principles in the HTML comment.

`{{PROJECT_PHASE}}` is replaced with the phase from the interview.

- [ ] **Step 2: Commit**

```bash
git add _knowledge/CLAUDE.md.template
git commit -m "feat(installer): CLAUDE.md.template with project placeholders"
```

---

### Task 3: Copy Universal Files into _knowledge/

**Files:**
- Create: entire `_knowledge/` tree with universal (non-parameterized) files

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p _knowledge/agents
mkdir -p _knowledge/meta/decisions
mkdir -p _knowledge/meta/docs
mkdir -p _knowledge/meta/drafts
mkdir -p _knowledge/.claude/hooks
mkdir -p _knowledge/.claude/commands
mkdir -p _knowledge/.claude/scripts
mkdir -p _knowledge/templates
```

- [ ] **Step 2: Copy universal files**

```bash
# Universal (no parameters needed)
cp "Full Attention Residuals.md" _knowledge/
cp agents/AGENT_PROTOCOL.md _knowledge/agents/
cp meta/sessions.md _knowledge/meta/
cp meta/drafts/.gitkeep _knowledge/meta/drafts/

# All hooks
cp .claude/hooks/*.sh _knowledge/.claude/hooks/

# All commands
cp .claude/commands/*.md _knowledge/.claude/commands/

# Scripts
cp .claude/scripts/context.py _knowledge/.claude/scripts/

# Templates
cp templates/extraction-template.json _knowledge/templates/
```

- [ ] **Step 3: Create empty template files**

Create `_knowledge/meta/roadmap.md`:
```markdown
# Roadmap

## Легенда
[ ] не начата | [~] начата/заморожена | [v] активна | [x] завершена

## Стек задач

### Глубина 0

## Сессионный контекст
→ meta/sessions.md (отдельный файл; при старте подгружается последний блок)
```

Create `_knowledge/meta/project_manifest.md`:
```markdown
# Project Manifest

> Карта файловой структуры проекта. Загружается по запросу.
> Заполняется при установке и обновляется при структурных изменениях.
```

Create `_knowledge/meta/_tags.md`:
```markdown
# Словарь хештегов

Общий для meta/decisions/ и meta/docs/. Новый тег → сначала добавь сюда + обоснуй.
```

Create `_knowledge/meta/decisions/_index.md`:
```markdown
# Decisions Hub
Решений: 0 | ■ 0 | ◆ 0 | ● 0
Доменные индексы: meta/decisions/{domain}/_index.md

Легенда: ■ АКСИОМА | ◆ ПРАВИЛО | ● ГИПОТЕЗА

## Домены
| Домен | Решений | Статистика | Описание |
|-------|---------|------------|----------|

## ⚠ Триггеры пересмотра
(пока пусто)
```

Create `_knowledge/meta/docs/_index.md`:
```markdown
# Карта исследований

Правило: перед ответом на вопрос по теме — прочитай файл. Не отвечай по памяти.
Доменные индексы: meta/docs/{topic}/_index.md

## Темы
| Тема | Документов | Описание |
|------|------------|----------|
```

- [ ] **Step 4: Create settings.local.json template**

Create `_knowledge/.claude/settings.local.json.template`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git commit:*)",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-commit-secretary.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-compact-handoff.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PostCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/post-compact-reload.sh",
            "timeout": 10
          }
        ]
      }
    ],
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
  }
}
```

- [ ] **Step 5: Verify all files exist**

```bash
find _knowledge -type f | sort
```

Expected: ~25 files covering all system components.

- [ ] **Step 6: Commit**

```bash
git add _knowledge/
git commit -m "feat(installer): _knowledge/ template folder with all system files"
```

---

### Task 4: install.sh

**Files:**
- Create: `install.sh`

- [ ] **Step 1: Create install script**

```bash
#!/bin/bash
# install.sh — Download Knowledge Management Kit template into current project
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/KinskyK/knowledge-management-kit/main/install.sh)"

set -euo pipefail

REPO="KinskyK/knowledge-management-kit"
BRANCH="main"
TARGET="_knowledge"

# Check if _knowledge already exists
if [ -d "$TARGET" ]; then
  echo "⚠ Папка _knowledge/ уже существует."
  echo "  Удалите её (rm -rf _knowledge) и запустите снова."
  exit 1
fi

echo "📦 Downloading Knowledge Management Kit..."

# Method 1: git clone (sparse checkout, fastest)
if command -v git &> /dev/null; then
  TEMP_DIR=$(mktemp -d)
  if git clone --depth 1 --filter=blob:none --sparse \
    "https://github.com/$REPO.git" "$TEMP_DIR" 2>/dev/null; then
    cd "$TEMP_DIR"
    git sparse-checkout set _knowledge 2>/dev/null
    cd - > /dev/null
    if [ -d "$TEMP_DIR/_knowledge" ]; then
      cp -r "$TEMP_DIR/_knowledge" .
      rm -rf "$TEMP_DIR"
      echo "✓ Скачано через git"
    else
      rm -rf "$TEMP_DIR"
      NEED_CURL=true
    fi
  else
    rm -rf "$TEMP_DIR"
    NEED_CURL=true
  fi
fi

# Method 2: Download zip and extract _knowledge/
if [ "${NEED_CURL:-false}" = true ] || ! command -v git &> /dev/null; then
  TEMP_ZIP=$(mktemp)
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.zip" -o "$TEMP_ZIP"
  TEMP_EXTRACT=$(mktemp -d)
  unzip -q "$TEMP_ZIP" -d "$TEMP_EXTRACT"
  EXTRACTED_DIR=$(ls "$TEMP_EXTRACT")
  if [ -d "$TEMP_EXTRACT/$EXTRACTED_DIR/_knowledge" ]; then
    cp -r "$TEMP_EXTRACT/$EXTRACTED_DIR/_knowledge" .
    echo "✓ Скачано через curl"
  else
    echo "✗ Ошибка: _knowledge/ не найдена в архиве"
    rm -rf "$TEMP_ZIP" "$TEMP_EXTRACT"
    exit 1
  fi
  rm -rf "$TEMP_ZIP" "$TEMP_EXTRACT"
fi

# Verify
if [ ! -f "_knowledge/INTEGRATION.md" ]; then
  echo "✗ Ошибка: INTEGRATION.md не найден"
  exit 1
fi

FILE_COUNT=$(find _knowledge -type f | wc -l | tr -d ' ')
echo ""
echo "✓ Knowledge Management Kit скачан ($FILE_COUNT файлов)"
echo ""
echo "Следующий шаг: откройте Claude Code и вставьте этот промпт:"
echo ""
echo '  В корне проекта лежит папка _knowledge/ — это шаблон системы управления знаниями.'
echo '  Прочитай _knowledge/INTEGRATION.md и выполни интеграцию. Веди меня по шагам.'
echo ""
```

- [ ] **Step 2: Make executable**

```bash
chmod +x install.sh
```

- [ ] **Step 3: Test locally**

```bash
# Test in a temp directory
TEMP=$(mktemp -d)
cp install.sh "$TEMP/"
cd "$TEMP"
bash install.sh
ls _knowledge/INTEGRATION.md && echo "OK"
cd -
rm -rf "$TEMP"
```

Note: this test will only work after `_knowledge/` is pushed to GitHub. For now, verify the script syntax:

```bash
bash -n install.sh && echo "Syntax OK"
```

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat(installer): install.sh — one-command download from GitHub"
```

---

### Task 5: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update installation section**

Replace the current "## Установка (2 шага)" section with an updated version that offers two methods:

Find `## Установка (2 шага)` and replace everything up to (but not including) `---` with:

```markdown
## Установка

### Способ 1: Один промпт (рекомендуемый)

Откройте Claude Code в папке вашего проекта и вставьте:

```
Скачай и установи Knowledge Management Kit:
bash -c "$(curl -fsSL https://raw.githubusercontent.com/KinskyK/knowledge-management-kit/main/install.sh)"
Потом прочитай _knowledge/INTEGRATION.md и выполни интеграцию. Веди меня по шагам.
```

Claude скачает систему, спросит о проекте и настроит всё автоматически.

### Способ 2: Ручная установка

```bash
# Скачать шаблон
curl -fsSL https://raw.githubusercontent.com/KinskyK/knowledge-management-kit/main/install.sh | bash

# Открыть Claude Code и вставить промпт:
# В корне проекта лежит папка _knowledge/. Прочитай _knowledge/INTEGRATION.md и выполни интеграцию.
```

### Что произойдёт

Claude:
- Спросит о проекте (название, описание, фаза, домены)
- Проверит, есть ли уже CLAUDE.md, и сольёт — или создаст новый
- Создаст директории и настроит хуки
- Удалит папку `_knowledge/` после завершения

Ты только отвечаешь на вопросы и подтверждаешь.
```

- [ ] **Step 2: Update "Хуки" description**

Find `6. **Хуки** — 6 хуков:`. Replace with:

```markdown
6. **Хуки** — 7 хуков: pre-commit (секретарский чеклист), session-start (восстановление контекста), session-end (автозахват черновиков), pre/post-compact (handoff при компрессии), rebuild-index (аварийное восстановление), lint-refs (валидация ссылок и контрактов).
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: update README — new install method + 7 hooks"
```

---

### Task 6: Verify Full Installation Flow

**Files:** none (verification task)

- [ ] **Step 1: Verify _knowledge/ contains all required files**

```bash
echo "=== Files in _knowledge/ ==="
find _knowledge -type f | sort
echo ""
echo "=== Expected components ==="
echo "INTEGRATION.md, CLAUDE.md.template, FAR spec, AGENT_PROTOCOL,"
echo "7 hooks, 7 commands, context.py, extraction template,"
echo "meta templates (roadmap, sessions, _tags, manifest, drafts, indexes),"
echo "settings.local.json.template"
echo ""
echo "=== Count ==="
find _knowledge -type f | wc -l
```

- [ ] **Step 2: Verify install.sh syntax**

```bash
bash -n install.sh && echo "install.sh: OK"
```

- [ ] **Step 3: Verify all hooks in _knowledge/ have correct syntax**

```bash
for f in _knowledge/.claude/hooks/*.sh; do
  bash -n "$f" && echo "$(basename $f): OK" || echo "$(basename $f): FAIL"
done
```

- [ ] **Step 4: Verify settings.local.json.template is valid JSON**

```bash
python3 -c "import json; json.load(open('_knowledge/.claude/settings.local.json.template')); print('JSON OK')"
```

- [ ] **Step 5: Commit verification results (if any fixes needed)**

```bash
git add -A && git commit -m "fix(installer): verification fixes" 2>/dev/null || echo "Nothing to fix"
```

- [ ] **Step 6: Push everything**

```bash
git push
```

---

## Summary

| Task | What | Key Output |
|------|------|------------|
| 1 | INTEGRATION.md | Claude-guided 7-step installation script |
| 2 | CLAUDE.md.template | Parameterized brief with {{placeholders}} |
| 3 | Universal files | ~25 files copied into _knowledge/ |
| 4 | install.sh | One-command download from GitHub |
| 5 | README.md update | New installation section + 7 hooks |
| 6 | Verification | All files valid, syntax checked |

**Total: 6 tasks, ~6 commits.**

**User flow after this plan:**
```
User opens Claude Code in their project
  ↓
Pastes one prompt (from README)
  ↓
Claude runs install.sh → downloads _knowledge/
  ↓
Claude reads INTEGRATION.md → asks 5 questions
  ↓
Claude generates all files → configures hooks
  ↓
Claude deletes _knowledge/ → "System installed"
  ↓
Optional: /graphrag init
```

**What about updates?** Update mechanism (update.sh) is deferred to a separate plan — it requires careful design around preserving user's decisions, sessions, and custom brief while updating hooks, commands, and scripts.
