# GraphRAG Extraction Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate triple extraction into the secretary protocol so Claude automatically feeds the knowledge graph at every commit. Create extraction templates, a Claude Code command, and update the pre-commit hook.

**Architecture:** Claude extracts triples (entities + relationships + chunks) from changed files during the secretary protocol. A new command `/graphrag extract` generates JSON from a given file. The pre-commit hook reminds Claude to run extraction for changed ADR/docs/sessions files. Extraction is only active when GraphRAG is configured (`.graphrag/config.yaml` exists).

**Tech Stack:** Bash (hooks), Markdown (commands), JSON (triple format)

**Depends on:** Plan 1 (MCP server with insert_kg tool must be available)

---

## File Structure

```
.claude/
├── commands/
│   └── graphrag-extract.md       # /graphrag extract command — guides Claude through extraction
├── hooks/
│   └── pre-commit-secretary.sh   # MODIFY: add GraphRAG extraction reminder (step 8)
templates/
└── extraction-template.json      # Reference: JSON schema for triples
```

---

### Task 1: Extraction Template

**Files:**
- Create: `templates/extraction-template.json`

- [ ] **Step 1: Create the extraction template with documentation**

```json
{
  "_doc": "Template for GraphRAG triple extraction. Claude fills this when extracting knowledge from ADR/docs/sessions files.",
  "_entity_types": ["decision", "concept", "problem", "domain", "mechanism", "file"],
  "_relationship_types": ["depends-on", "influences", "solves", "part-of", "supersedes", "rejected", "requires", "enables", "contradicts"],
  "entities": [
    {
      "entity_name": "ENTITY_NAME — use canonical form, e.g. 'FAR Protocol' not 'FAR' or 'Full Attention Residuals'",
      "entity_type": "one of: decision | concept | problem | domain | mechanism | file",
      "description": "1-2 sentences: what this entity is and why it matters. Include key properties.",
      "source_id": "relative/path/to/source/file.md"
    }
  ],
  "relationships": [
    {
      "src_id": "source entity_name (must match an entity_name exactly)",
      "tgt_id": "target entity_name (must match an entity_name exactly)",
      "description": "What is the nature of this relationship? Be specific.",
      "keywords": "relationship-type, additional-keywords",
      "weight": 1.0,
      "source_id": "relative/path/to/source/file.md"
    }
  ],
  "chunks": [
    {
      "content": "Full text or key section of the source document. Include enough context for semantic search.",
      "source_id": "relative/path/to/source/file.md"
    }
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add templates/extraction-template.json
git commit -m "feat(graphrag): extraction template with entity/relationship type vocabulary"
```

---

### Task 2: /graphrag extract Command

**Files:**
- Create: `.claude/commands/graphrag-extract.md`

- [ ] **Step 1: Create the command file**

```markdown
Extract knowledge graph triples from a file and insert into GraphRAG.

Argument: file path (e.g. `meta/decisions/core/CORE-01.md`) or `--changed` for all changed files.

## Instructions

### Step 1: Read the file

Read the file specified in $ARGUMENTS. If `--changed`, run `git diff --name-only HEAD` and process each .md file in meta/decisions/, meta/docs/, meta/sessions.md.

### Step 2: Extract triples

From the file content, identify:

**Entities** (things that exist):
- Decisions (codes like DSN-001, CORE-01)
- Concepts (FAR Protocol, secretary protocol, lazy loading)
- Problems (context overflow, lost knowledge between sessions)
- Mechanisms (pre-commit hook, context.py, rebuild-index)
- Files (sessions.md, roadmap.md, CLAUDE.md)
- Domains (core, integration)

Use canonical names — always the same form for the same entity. Check existing entities with `graph_stats` or `check_entity` before creating duplicates.

**Relationships** (how entities connect):
- From ADR fields: "Зависит от" → depends-on, "Влияет на" → influences
- From ADR "Отвергнуто" → rejected (src=decision, tgt=rejected alternative)
- From text: solves, part-of, requires, enables, contradicts, supersedes

**Chunks** (searchable text):
- For ADR: include the full "Решение" + "Почему" sections
- For docs: include the summary/conclusion
- For sessions: include the full session block

### Step 3: Format as JSON

Follow the schema from `templates/extraction-template.json`.

Entity types: decision, concept, problem, domain, mechanism, file
Relationship keywords: depends-on, influences, solves, part-of, supersedes, rejected, requires, enables, contradicts

Weight: 1.0 for explicit ADR links (Зависит от / Влияет на), 0.7-0.9 for inferred relationships.

### Step 4: Insert into GraphRAG

If an MCP tool `insert_kg` is available, call it with the JSON.

If the file was previously indexed, first call `delete_by_source` with the file path to remove old triples, then insert new ones.

### Step 5: Confirm

Report: "Extracted N entities, M relationships from [file]. Inserted into GraphRAG."
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/graphrag-extract.md
git commit -m "feat(graphrag): /graphrag extract command for triple extraction"
```

---

### Task 3: Update Pre-Commit Hook

**Files:**
- Modify: `.claude/hooks/pre-commit-secretary.sh`

- [ ] **Step 1: Add GraphRAG extraction reminder to the secretary checklist**

After line 75 (echo "  7. Новый файл → обновлён _index.md (доменный + hub)?"), add:

```bash
# GraphRAG extraction reminder (only if configured)
if [ -f ".graphrag/config.yaml" ]; then
  echo "  8. GraphRAG: извлечь тройки из изменённых файлов → /graphrag extract --changed"

  # Check if any ADR/docs/sessions changed but GraphRAG might not be updated
  HAS_GRAPHRAG_CANDIDATES=false
  for file in $CHANGED; do
    case "$file" in
      meta/decisions/*/*.md|meta/docs/*/*.md|meta/sessions.md)
        case "$file" in
          */_index.md|*/_tags.md) ;;
          *) HAS_GRAPHRAG_CANDIDATES=true ;;
        esac
        ;;
    esac
  done

  if [ "$HAS_GRAPHRAG_CANDIDATES" = true ]; then
    WARNINGS="${WARNINGS}\n⚠ Файлы для GraphRAG изменены. Запусти /graphrag extract --changed перед коммитом."
  fi
fi
```

- [ ] **Step 2: Verify hook syntax**

```bash
bash -n .claude/hooks/pre-commit-secretary.sh && echo "OK"
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add .claude/hooks/pre-commit-secretary.sh
git commit -m "feat(graphrag): pre-commit hook reminds about triple extraction"
```

---

### Task 4: Update CLAUDE.md — Secretary Protocol Step 8

**Files:**
- Modify: `CLAUDE.md:63-70`

- [ ] **Step 1: Add step 8 to secretary protocol**

After line 70 (item 7 of secretary protocol), add:

```markdown
  8. GraphRAG настроен? → извлечь тройки из изменённых файлов: `/graphrag extract --changed`
```

- [ ] **Step 2: Verify CLAUDE.md stays under 200 lines**

```bash
wc -l CLAUDE.md
```
Expected: < 200

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "feat(graphrag): secretary protocol step 8 — triple extraction at commit"
```

---

### Task 5: Update AGENT_PROTOCOL.md — Extraction Guidelines

**Files:**
- Modify: `agents/AGENT_PROTOCOL.md`

- [ ] **Step 1: Add extraction section after "Протокол фиксации решений"**

After the ADR format section (line 61), before "Жизненный цикл ⚠ триггеров пересмотра", add:

```markdown
---

## Протокол извлечения троек (GraphRAG)

При наличии GraphRAG (`/graphrag extract` доступен):

После записи/изменения ADR — извлеки тройки:
1. Сущности: решение (код), связанные концепции, проблемы, механизмы
2. Связи: из полей "Зависит от"/"Влияет на" (weight 1.0) + из текста (weight 0.7-0.9)
3. Чанки: секции "Решение" + "Почему" + "Отвергнуто"

Каноничность имён: одна сущность = одно имя. "FAR Protocol", не "FAR" / "Full Attention Residuals" / "ФАР". Проверяй `check_entity` перед созданием.

Типы сущностей: decision, concept, problem, domain, mechanism, file.
Типы связей: depends-on, influences, solves, part-of, supersedes, rejected, requires, enables, contradicts.

Шаблон: `templates/extraction-template.json`.
```

- [ ] **Step 2: Commit**

```bash
git add agents/AGENT_PROTOCOL.md
git commit -m "feat(graphrag): extraction protocol in AGENT_PROTOCOL.md"
```

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | Extraction template | templates/extraction-template.json |
| 2 | /graphrag extract command | .claude/commands/graphrag-extract.md |
| 3 | Pre-commit hook update | .claude/hooks/pre-commit-secretary.sh |
| 4 | CLAUDE.md step 8 | CLAUDE.md |
| 5 | AGENT_PROTOCOL extraction guidelines | agents/AGENT_PROTOCOL.md |

**Total: 5 tasks, 5 commits.**

After this plan: Claude knows how to extract triples, when to do it (step 8 of secretary protocol), and how to format them. Pre-commit hook reminds about extraction when relevant files change. Everything is conditional on GraphRAG being configured.
