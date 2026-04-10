Extract knowledge graph triples from a file and insert into GraphRAG.

Argument: file path (e.g. `meta/decisions/core/CORE-01.md`) or `--changed` for all changed files.

## Instructions

### Step 1: Determine files to process

If `$ARGUMENTS` is a specific file path -- read that file.

If `$ARGUMENTS` is `--changed` -- run:

```bash
git diff --name-only HEAD
```

Filter the output: process only `.md` files matching these paths:
- `meta/decisions/**/*.md` (but NOT `_index.md`, `_tags.md`)
- `meta/docs/**/*.md` (but NOT `_index.md`)
- `meta/sessions.md`

If no files match, report "No files to extract" and stop.

### Step 2: For each file, extract triples

Read the file content. From it, identify three categories:

**Entities** (things that exist):

| Type | What to look for | Name convention |
|------|-------------------|-----------------|
| decision | ADR codes like CORE-01, FEAT-02, INT-01 | The code itself: `CORE-01` |
| concept | Named ideas, patterns, protocols (FAR, secretary protocol, lazy loading) | Canonical form: `FAR Protocol`, not `FAR` or `Full Attention Residuals` |
| problem | Problems being solved (context overflow, lost knowledge between sessions) | Short noun phrase: `Context Overflow` |
| mechanism | Tools, scripts, hooks (pre-commit hook, context.py, rebuild-index) | Specific name: `context.py`, `pre-commit-secretary hook` |
| file | Referenced files (sessions.md, roadmap.md, CLAUDE.md) | Relative path: `meta/sessions.md` |
| domain | Knowledge domains (core, integration, features) | Lowercase: `core`, `integration` |

Before creating an entity, call the `check_entity` MCP tool with its canonical name. If it already exists, reuse the existing name exactly -- do not create a duplicate.

**Relationships** (how entities connect):

| Source | Pattern | Keyword | Weight |
|--------|---------|---------|--------|
| ADR field | "Depends on:" / "Depends on:" | depends-on | 1.0 |
| ADR field | "Influences:" / "Influences:" | influences | 1.0 |
| ADR section | "Rejected" alternatives | rejected | 1.0 |
| Text | X solves problem Y | solves | 0.8 |
| Text | X is part of Y | part-of | 0.8 |
| Text | X supersedes Y | supersedes | 0.9 |
| Text | X requires Y | requires | 0.7 |
| Text | X enables Y | enables | 0.7 |
| Text | X contradicts Y | contradicts | 0.8 |

Both `src_id` and `tgt_id` must match an `entity_name` exactly from the entities list.

**Chunks** (searchable text sections):

| File type | What to include |
|-----------|-----------------|
| ADR (decisions/) | Full text of "Decision" + "Why" sections |
| Research (docs/) | Summary or conclusion section |
| Sessions (sessions.md) | Each session block as a separate chunk |

### Step 3: Format as JSON

Structure the extraction as JSON matching the schema from `templates/extraction-template.json`:

```json
{
  "entities": [
    {
      "entity_name": "Canonical Name",
      "entity_type": "decision|concept|problem|domain|mechanism|file",
      "description": "1-2 sentences: what this is and why it matters.",
      "source_id": "relative/path/to/source.md"
    }
  ],
  "relationships": [
    {
      "src_id": "Source Entity Name",
      "tgt_id": "Target Entity Name",
      "description": "Nature of this relationship.",
      "keywords": "depends-on, additional-keyword",
      "weight": 1.0,
      "source_id": "relative/path/to/source.md"
    }
  ],
  "chunks": [
    {
      "content": "Key text section from the document.",
      "source_id": "relative/path/to/source.md"
    }
  ]
}
```

### Step 4: Delete old triples if re-indexing

Before inserting, call the `delete_by_source` MCP tool with the file path to remove any previously extracted triples from this file:

```
delete_by_source(source_id="relative/path/to/source.md")
```

This ensures a clean re-index -- no stale entities or relationships linger.

### Step 5: Insert into GraphRAG

Call the `insert_kg` MCP tool. The `custom_kg` parameter takes a JSON string:

```
insert_kg(custom_kg="{...the JSON from Step 3...}")
```

### Step 6: Report results

For each processed file, report:

```
[file path] -- extracted N entities, M relationships, K chunks. Inserted into GraphRAG.
```

If processing multiple files (`--changed`), show a summary at the end:

```
Total: N entities, M relationships, K chunks from X files.
```
