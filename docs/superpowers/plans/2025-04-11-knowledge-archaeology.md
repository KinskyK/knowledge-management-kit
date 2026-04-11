# Knowledge Archaeology Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `/knowledge-archaeology` command that extracts decisions from project history (Claude Code sessions + git log) and generates ADR files retroactively.

**Architecture:** Four phases: (1) Extract — read sessions/git in chronological chunks, write raw drafts to meta/drafts/. (2) Build evolution trees — group drafts by topic, trace how each decision changed over time. (3) Compile — from the tip of each tree (current state), generate ADR files with Эволюция and Отвергнуто sections. (4) Optional review — user can review each ADR or accept all at once.

**Tech Stack:** Markdown (command file), Bash (session file discovery). All logic is behavioral — Claude reads files and writes ADR. No new dependencies.

**Impact on existing system:** NONE. This is a new command file only. Does not modify any hooks, protocols, existing commands, or the installer. The command writes to meta/drafts/ (existing infrastructure) and meta/decisions/ (existing structure). After completion, the normal secretary protocol and GraphRAG extraction apply to new files.

---

## File Structure

```
.claude/commands/
└── knowledge-archaeology.md      # NEW: /knowledge-archaeology command
_knowledge/.claude/commands/
└── knowledge-archaeology.md      # NEW: copy for installer distribution
```

Two files, identical. One for the current project, one for the installer template.

**What is NOT changed:**
- No hooks modified
- No CLAUDE.md changes
- No AGENT_PROTOCOL.md changes
- No settings.local.json changes
- No installer changes (just one file added to _knowledge/)

---

### Task 1: /knowledge-archaeology Command

**Files:**
- Create: `.claude/commands/knowledge-archaeology.md`

- [ ] **Step 1: Create the command file**

```markdown
Retroactive knowledge extraction — read project history and generate ADR files from past decisions.

Use this when a project has history (sessions, git commits) but no documented decisions.

## Overview

Four phases:
1. **Extract** — read history in chunks, write raw drafts
2. **Build evolution trees** — group by topic, trace changes
3. **Compile** — generate ADR files from current state of each decision
4. **Review** — optional user review

## Phase 1: Extract

### Step 1.1: Discover sources

Check what history is available:

**Claude Code sessions:**
```bash
ls ~/.claude/projects/*/  2>/dev/null | head -20
```

Find the project directory that matches the current project path. Session files are `.jsonl` — each line is a JSON record with type "user" or "assistant".

**Git history:**
```bash
git log --oneline --since="6 months ago" | wc -l
```

Tell the user: "Найдено: N сессий Claude Code, M коммитов за 6 месяцев. Начинаю извлечение."

If no sessions AND no git history: "Нет истории для анализа. Начни работу и используй секретарский протокол для документирования решений."

### Step 1.2: Read sessions in chunks

For each session file (chronologically, oldest first):

Read 50 user+assistant message pairs at a time (one chunk). For each chunk, extract:

- **Decisions**: "решили X", "выбрали Y", "будем делать Z", "отказались от W"
- **Problems found**: "не работает", "сломалось", "баг", "ошибка" → что было и как решили
- **Approach changes**: "раньше делали X, теперь Y", "переходим на Z"
- **Technical choices**: библиотеки, архитектура, форматы, протоколы

For each chunk, write a draft to `meta/drafts/`:

Filename: `archaeology-YYYY-MM-DD-NNN.md` where date is from the session and NNN is chunk number.

Format:
```
### Черновик археологии: [сессия от YYYY-MM-DD, часть N]

#### Решения
- **[Решение]**: [контекст]. Почему: [причина]. Отвергнуто: [что, если упомянуто].

#### Проблемы
- **[Проблема]**: [суть] → [решение]

#### Изменения подхода
- **Было:** [X]. **Стало:** [Y]. **Почему:** [причина]
```

Skip chunks that contain only code output, tool results, or routine work without decisions. Write draft only if there's at least one decision, problem, or approach change.

After each session file: report "Сессия YYYY-MM-DD: N черновиков из M частей."

### Step 1.3: Read git history (if no sessions or as supplement)

If session files unavailable or for additional context:

```bash
git log --format="%H %ai %s" --since="6 months ago" --reverse
```

Group commits by week. For each week with significant commits (not just "fix typo"):
- Read commit messages
- For merge commits or large changes: read `git show --stat <hash>` to understand scope
- Extract decisions from commit messages: "migrate to X", "replace Y with Z", "add feature W"

Write drafts in same format, filename: `archaeology-git-YYYY-MM-DD.md`.

### Step 1.4: Report extraction results

"Фаза 1 завершена. Извлечено N черновиков из K сессий и M коммитов."

## Phase 2: Build Evolution Trees

### Step 2.1: Read all archaeology drafts

```bash
ls meta/drafts/archaeology-*.md
```

Read all drafts in chronological order.

### Step 2.2: Group by topic

Identify unique decisions/topics across all drafts. Same decision may appear in multiple drafts with different states:

Example:
- Draft from March: "Решили хранить данные в одном файле"
- Draft from April: "Перешли на отдельные файлы — один файл стал слишком большим"
- Draft from May: "Добавили двухуровневые индексы поверх отдельных файлов"

This is ONE topic with THREE states → evolution chain.

Group into topics. For each topic, build chronological chain:
```
Topic: "Формат хранения данных"
v1 (March): один файл
v2 (April): отдельные файлы → v1 rejected (слишком большой файл)
v3 (May): отдельные файлы + индексы → v2 extended
Current: v3
```

### Step 2.3: Identify current state

For each topic, the last entry in the chain is the current decision. Earlier entries are history (Эволюция) and rejected alternatives (Отвергнуто).

Write consolidated file: `meta/drafts/archaeology-consolidated.md` with all topics and their evolution chains.

Report: "Фаза 2 завершена. Найдено N уникальных решений, из них M прошли эволюцию."

## Phase 3: Compile ADR Files

### Step 3.1: Ask about domains

"Перед генерацией ADR: какие домены решений использовать?"

If `meta/decisions/` already has domain directories — use them.
If not — suggest domains based on topics found. Ask user to confirm.

Create domain directories if needed:
```bash
mkdir -p meta/decisions/{{domain}}
```

### Step 3.2: Generate ADR files

For each unique current decision, create an ADR file in the appropriate domain:

Filename: `meta/decisions/{{domain}}/{{CODE}}.md`

Code assignment: `{{DOMAIN_PREFIX}}-01`, `{{DOMAIN_PREFIX}}-02`, etc. Uppercase prefix from domain name (e.g., domain "core" → CORE-01).

ADR format (from AGENT_PROTOCOL.md):
```
# {{CODE}} — {{название}}

#{{теги}}

- **Зависит от**: [[коды]] (if dependencies found in history)
- **Влияет на**: [[коды]] (if impacts found)
- **Решение**: [текущее состояние — v3 from evolution chain]
- **Почему**: [обоснование из истории]
- **Пересмотреть если**: [условия, если очевидны из контекста]
- **Статус**: accepted ◆ ПРАВИЛО

**Отвергнуто:**
- [v1/v2 from evolution chain — что пробовали и почему отказались]

**Эволюция v1→vN:**
- v1 (дата): [что было]
- v2 (дата): [что изменилось и почему]
- ...current
```

If the decision never changed (no evolution): skip Эволюция section, include Отвергнуто only if alternatives were discussed.

### Step 3.3: Update indexes

For each domain with new ADR files:
- Update `meta/decisions/{{domain}}/_index.md` — add entries
- Update `meta/decisions/_index.md` (hub) — update counts

Update `meta/_tags.md` if new tags were created.

### Step 3.4: Report

"Фаза 3 завершена. Сгенерировано N ADR-файлов в M доменах."

## Phase 4: Optional Review

### Step 4.1: Ask user

"Сгенерировано N решений. Хочешь просмотреть каждое? (да — покажу по одному, нет — всё готово, можешь просмотреть в meta/decisions/)"

### Step 4.2: If yes — review each

For each ADR file:
- Show content
- Ask: "Верно? (да / исправить / удалить)"
- If "исправить" — ask what to change, update file
- If "удалить" — remove file, update index

### Step 4.3: If no — done

"Все файлы сохранены в meta/decisions/. Просмотри когда будет время."

## Phase 5: Cleanup

Delete processed archaeology drafts:
```bash
rm meta/drafts/archaeology-*.md
```

Keep meta/drafts/archaeology-consolidated.md as reference (or delete if user prefers).

Report final: "Археология завершена. N решений задокументировано. Система управления знаниями готова к работе."

If GraphRAG configured: "Запусти `/graphrag extract --changed` чтобы проиндексировать новые ADR в граф знаний."
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/knowledge-archaeology.md
git commit -m "feat: /knowledge-archaeology command — retroactive knowledge extraction"
```

---

### Task 2: Add to Installer Template

**Files:**
- Create: `_knowledge/.claude/commands/knowledge-archaeology.md`

- [ ] **Step 1: Copy command to _knowledge/**

```bash
cp .claude/commands/knowledge-archaeology.md _knowledge/.claude/commands/knowledge-archaeology.md
```

- [ ] **Step 2: Verify**

```bash
diff .claude/commands/knowledge-archaeology.md _knowledge/.claude/commands/knowledge-archaeology.md
```
Expected: no differences.

- [ ] **Step 3: Commit**

```bash
git add _knowledge/.claude/commands/knowledge-archaeology.md
git commit -m "feat(installer): add knowledge-archaeology to _knowledge/ template"
```

---

### Task 3: Update README.md — Mention Archaeology

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add archaeology mention**

Find the line `**Можно ли без агентов?**` in the FAQ section. Insert BEFORE it:

```markdown
**Проект уже идёт, решения не документировались?** Запусти `/knowledge-archaeology` — Claude пройдёт по истории сессий и git, найдёт решения и сгенерирует ADR-файлы.

```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: mention /knowledge-archaeology in README FAQ"
```

---

### Task 4: Update Architecture Map

**Files:**
- Modify: `docs/architecture-map.md`

- [ ] **Step 1: Add archaeology section**

Find the section "## Обзор: анатомия системы" (the summary diagram). Insert BEFORE it a new top-level section:

```markdown

## Археология знаний — для проектов с историей

Если проект уже шёл без системы управления знаниями — решения принимались, но не записывались. Команда `/knowledge-archaeology` проходит по истории (сессии Claude Code + git log) и восстанавливает решения ретроспективно.

Четыре фазы: (1) извлечение из сессий и git порциями → черновики в meta/drafts/. (2) Группировка по темам, построение цепочек эволюции (решение X → изменено на Y → расширено до Z). (3) Компиляция: на конце каждой ветки — актуальное решение → ADR-файл. Промежуточные версии → секция "Эволюция", отвергнутые → "Отвергнуто". (4) Опциональный просмотр — пользователь решает, проверять каждый ADR или принять все.

Это не замена секретарского протокола — это одноразовая операция для проектов, начавших без документации.
```

- [ ] **Step 2: Commit**

```bash
git add docs/architecture-map.md
git commit -m "docs: knowledge archaeology in architecture map"
```

---

## Impact Analysis

| Component | Affected? | How |
|-----------|-----------|-----|
| CLAUDE.md | No | No changes |
| AGENT_PROTOCOL.md | No | Archaeology generates ADR in existing format |
| Hooks (7) | No | No hook changes. Archaeology writes to meta/drafts/ and meta/decisions/ — existing hooks will work with these files normally |
| Secretary protocol | No | After archaeology, normal protocol applies at next commit |
| GraphRAG | No | Archaeology generates ADR files. User runs /graphrag extract to index them (mentioned in command's Phase 5) |
| Installer | Minimal | One file added to _knowledge/.claude/commands/ |
| settings.local.json | No | No hook registration needed — this is a manual command |
| FAR protocol | No | No changes |

**Meta/drafts/ usage:** Archaeology writes drafts with prefix `archaeology-`. Normal auto-capture drafts have date prefix. No collision. Pre-commit hook counts all .md files in drafts/ — archaeology drafts will show in the count, which is correct (they need processing).

**Session file reading:** Read-only. No modification to JSONL files. Uses standard bash (ls, cat) + Claude's intelligence to parse.

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | /knowledge-archaeology command | .claude/commands/knowledge-archaeology.md |
| 2 | Copy to installer template | _knowledge/.claude/commands/knowledge-archaeology.md |
| 3 | README FAQ mention | README.md |
| 4 | Architecture map section | docs/architecture-map.md |

**Total: 4 tasks, 4 commits.**

**Risk: ZERO for existing system.** Two new files (command + installer copy) and two doc updates. No hooks, protocols, or settings changed.
