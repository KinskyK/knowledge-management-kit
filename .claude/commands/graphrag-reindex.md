Emergency full rebuild of the knowledge graph. Clears all data and re-indexes from scratch.

## Instructions

### Step 1: Verify GraphRAG is configured

Check that `.graphrag/config.yaml` exists:

```bash
ls .graphrag/config.yaml 2>/dev/null
```

If it does not exist -- tell the user: "GraphRAG не настроен. Запусти /graphrag init." Stop.

Call the `graph_stats` MCP tool to verify the server is responding.

If it fails -- tell the user: "MCP-сервер не отвечает. Проверь, что graphrag_mcp установлен и настроен (/graphrag init)." Stop.

### Step 2: Confirm with user

Ask: "Это пересоздаст весь граф знаний с нуля. Текущие данные будут удалены. Продолжить? (yes/no)"

If the user says no -- stop.

### Step 3: Clear existing data

```bash
rm -rf .graphrag/data/*
```

Tell the user: "Данные графа очищены. Начинаю индексацию..."

### Step 4: Find all knowledge files

```bash
find meta/decisions -name "*.md" ! -name "_index.md" ! -name "_tags.md" 2>/dev/null
find meta/docs -name "*.md" ! -name "_index.md" 2>/dev/null
```

Also include `meta/sessions.md` if it exists.

Count total files to process.

### Step 5: Extract and insert

For each file, report progress:

```
[N/M] Extracting: <path>...
```

For each file: extract triples using `/graphrag extract <path>` logic (Steps 2-5 from graphrag-extract.md) and insert via `insert_kg`.

### Step 6: Report results

Call `graph_stats`. Report:

```
Reindex complete. N nodes, M relationships in the graph.
Processed X files.
```
