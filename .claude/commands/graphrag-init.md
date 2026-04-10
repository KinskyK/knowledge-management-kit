Initialize GraphRAG for this project. Installs dependencies, creates config, indexes existing knowledge.

## Instructions

### Step 1: Check if already configured

Check if `.graphrag/config.yaml` exists.

If it does -- ask: "GraphRAG already configured. Reinitialize? (yes/no)"

If the user says no -- stop.

### Step 2: Install dependencies

Check if `graphrag_mcp/.venv` exists:

```bash
ls graphrag_mcp/.venv/bin/python3 2>/dev/null
```

If it does not exist, create the venv and install dependencies:

```bash
cd graphrag_mcp && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
```

Tell the user: "Installing dependencies. On first run, the embedding model (~2.2 GB) will be downloaded -- this will take a few minutes."

### Step 3: Configure

Ask: "Do you have an OpenRouter API key? If not, create one for free at https://openrouter.ai/keys (needed for knowledge graph maintenance, free Gemma 3 model)."

Wait for the user to provide the key.

Create `.graphrag/config.yaml`:

```yaml
working_dir: .graphrag/data
embedding_model: intfloat/multilingual-e5-large
embedding_dim: 1024
max_token_size: 512
openrouter_api_key: "<user's key>"
openrouter_model: google/gemma-3-12b-it:free
```

Replace `<user's key>` with the actual key the user provided.

### Step 4: Add MCP server to Claude Code config

Read `.claude/settings.local.json`. If it does not exist, create it with an empty `mcpServers` object.

Add under `mcpServers`:

```json
{
  "graphrag": {
    "command": "graphrag_mcp/.venv/bin/python3",
    "args": ["-m", "graphrag_mcp.server"]
  }
}
```

Preserve any existing entries in `mcpServers`.

### Step 5: Verify MCP connection

Call the `graph_stats` MCP tool. If it responds -- MCP is connected.

If it fails -- check that `graphrag_mcp/.venv` exists and requirements are installed. Retry once after fixing.

### Step 6: Initial indexing

Find all existing knowledge files:

```bash
find meta/decisions -name "*.md" ! -name "_index.md" ! -name "_tags.md" 2>/dev/null
find meta/docs -name "*.md" ! -name "_index.md" 2>/dev/null
```

Count total files. For each file, report progress:

```
Indexing file N of M: <path>...
```

For each file: extract triples using `/graphrag extract <file>` and insert via `insert_kg`.

### Step 7: Verify and report

Call `graph_stats`. Report:

```
GraphRAG ready. N nodes, M relationships in the graph.
```

### Step 8: Update .gitignore

Ensure these lines are present in `.gitignore` (add if missing, do not duplicate):

```
.graphrag/data/
.graphrag/config.yaml
```
