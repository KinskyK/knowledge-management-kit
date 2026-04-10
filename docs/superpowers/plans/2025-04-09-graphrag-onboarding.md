# GraphRAG Onboarding Plan (v2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create onboarding commands for the GraphRAG layer: /graphrag init (per-project setup), /search (semantic search), /graphrag reindex (rebuild), updated README. Local-first — no VPS required.

**Architecture:** Same pattern as existing kit onboarding: user runs a command, Claude does the work. /graphrag init installs dependencies, creates config, indexes existing files. /search calls MCP tool. Future: VPS deployment as optional upgrade.

**Tech Stack:** Markdown (commands), Bash (verification)

**Depends on:** Plan 1 (MCP server exists), Plan 2 (extraction command exists)

---

## File Structure

```
.claude/commands/
├── graphrag-init.md           # /graphrag init — per-project setup
├── graphrag-reindex.md        # /graphrag reindex — rebuild from scratch
└── search.md                  # /search — semantic search
README.md                      # MODIFY: add GraphRAG section
```

---

### Task 1: /graphrag init Command

**Files:**
- Create: `.claude/commands/graphrag-init.md`

- [ ] **Step 1: Write the command file**

```markdown
Initialize GraphRAG for this project. Installs dependencies, creates config, indexes existing knowledge.

## Instructions

### Step 1: Check if already configured

If `.graphrag/config.yaml` exists — ask: "GraphRAG уже настроен. Переинициализировать? (да/нет)"

### Step 2: Install dependencies

Check if graphrag_mcp/.venv exists:
```bash
ls graphrag_mcp/.venv/bin/python3 2>/dev/null
```

If not:
```bash
cd mcp && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
```

Tell the user: "Устанавливаю зависимости. При первом запуске скачается embedding-модель (~2.2 GB) — это займёт несколько минут."

### Step 3: Configure

Ask: "Есть ли у тебя OpenRouter API key? Если нет — создай бесплатно на https://openrouter.ai/keys (нужен для обслуживания графа знаний, бесплатная модель Gemma 3)."

Create `.graphrag/config.yaml`:
```yaml
working_dir: .graphrag/data
embedding_model: intfloat/multilingual-e5-large
embedding_dim: 1024
max_token_size: 512
openrouter_api_key: "<user's key>"
openrouter_model: google/gemma-3-12b-it:free
```

### Step 4: Add MCP server to Claude Code config

Read `.claude/settings.local.json`. Add under "mcpServers":
```json
{
  "graphrag": {
    "command": "graphrag_mcp/.venv/bin/python3",
    "args": ["-m", "graphrag_mcp.server"]
  }
}
```

### Step 5: Verify MCP connection

Call `graph_stats` tool. If it responds — MCP is connected.
If it fails — check that graphrag_mcp/.venv exists and requirements are installed.

### Step 6: Initial indexing

Find all existing knowledge files:
```bash
find meta/decisions -name "*.md" ! -name "_index.md" ! -name "_tags.md" 2>/dev/null
find meta/docs -name "*.md" ! -name "_index.md" 2>/dev/null
```

For each file: extract triples using `/graphrag extract <file>` and insert via `insert_kg`.

Report progress: "Индексирую файл N из M: <path>..."

### Step 7: Verify

Call `graph_stats`. Report: "GraphRAG готов. N узлов, M связей в графе."

### Step 8: Update .gitignore

Ensure these lines are in .gitignore:
```
.graphrag/data/
.graphrag/config.yaml
```
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/graphrag-init.md
git commit -m "feat(graphrag): /graphrag init command for per-project setup"
```

---

### Task 2: /search Command

**Files:**
- Create: `.claude/commands/search.md`

- [ ] **Step 1: Write the command file**

```markdown
Search the knowledge graph by meaning.

Argument: search query in natural language (e.g. "как управлять контекстом в длинной сессии").

## Instructions

### Step 1: Check GraphRAG availability

If MCP tool `search_knowledge` is not available:
- "GraphRAG не настроен. Запусти `/graphrag init` для подключения."
- Предложи альтернативу: "Могу поискать через индексы и /context."

### Step 2: Search

Call `search_knowledge` with:
- query: $ARGUMENTS
- mode: "hybrid"

### Step 3: Present results

Read the returned context. Synthesize a useful answer:
- Какие сущности и связи найдены
- Как они относятся к запросу
- Пути к файлам для дальнейшего чтения

Если результатов нет: "По запросу ничего не найдено. Попробуй другие слова или проверь `/graphrag reindex`."
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/search.md
git commit -m "feat(graphrag): /search command for semantic knowledge search"
```

---

### Task 3: /graphrag reindex Command

**Files:**
- Create: `.claude/commands/graphrag-reindex.md`

- [ ] **Step 1: Write the command file**

```markdown
Rebuild the entire GraphRAG knowledge graph from scratch.

Like rebuild-index.sh for the file-based system — emergency tool.

## When to use

- After first install (done automatically by /graphrag init)
- After corrupted graph
- After bulk file changes outside normal workflow
- After changing embedding model

## Instructions

### Step 1: Verify GraphRAG configured

Check `.graphrag/config.yaml` exists and `graph_stats` tool responds.

### Step 2: Confirm

Ask: "Это пересоздаст весь граф с нуля. Продолжить? (да/нет)"

### Step 3: Clear data

```bash
rm -rf .graphrag/data/*
```

### Step 4: Find all knowledge files

```bash
find meta/decisions -name "*.md" ! -name "_index.md" ! -name "_tags.md" 2>/dev/null
find meta/docs -name "*.md" ! -name "_index.md" 2>/dev/null
ls meta/sessions.md 2>/dev/null
```

### Step 5: Extract and insert

For each file:
1. Read file
2. Extract triples (same as /graphrag extract)
3. Call insert_kg
4. Report: "Файл N/M: <path> — N сущностей, M связей"

### Step 6: Verify

Call `graph_stats`. Report totals.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/graphrag-reindex.md
git commit -m "feat(graphrag): /graphrag reindex command for emergency rebuild"
```

---

### Task 4: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add GraphRAG section after FAQ**

Append after the last line of README.md:

```markdown

---

## GraphRAG — семантический поиск + граф знаний (опционально)

При росте проекта навигация по индексам может не находить неявные связи. GraphRAG добавляет:

- **Поиск по смыслу** — "как мы решали проблему с контекстом" находит FAR-протокол, даже если слово "FAR" не в запросе
- **Граф знаний** — автоматически обнаруживает связи между решениями
- **Комбинированный поиск** — ищет одновременно по смыслу и по графу связей

### Установка

В Claude Code в папке проекта:

```
/graphrag init
```

Claude установит зависимости, спросит OpenRouter API key (бесплатно) и проиндексирует существующие файлы.

### Использование

- `/search <запрос>` — поиск по смыслу в графе знаний
- `/graphrag extract --changed` — извлечь тройки из изменённых файлов (автоматически при коммите)
- `/graphrag reindex` — пересоздать граф с нуля

### Стоимость

- Embedding-модель: локально, бесплатно
- OpenRouter (обслуживание графа): бесплатно (Gemma 3) или ~$0.05/мес
- VPS не нужен — всё работает на твоём компьютере
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add GraphRAG section to README"
```

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | /graphrag init | .claude/commands/graphrag-init.md |
| 2 | /search | .claude/commands/search.md |
| 3 | /graphrag reindex | .claude/commands/graphrag-reindex.md |
| 4 | README update | README.md |

**Total: 4 tasks, 4 commits.**

**After all three plans:**
- Plan 1: Local MCP server with LightRAG embedded (8 tasks)
- Plan 2: Extraction templates + secretary protocol (5 tasks)
- Plan 3: Onboarding commands + README (4 tasks)
- **Grand total: 17 tasks**

Future: VPS deployment (Docker Compose + Caddy + install script) as separate plan when needed.
