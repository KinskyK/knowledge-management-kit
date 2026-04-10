# GraphRAG MCP Server

Semantic search + knowledge graph for Knowledge Management Kit.
Runs locally -- LightRAG embedded inside MCP server process.

## Quick Start

### 1. Install

```bash
cd graphrag_mcp
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

First run downloads the embedding model (~2.2 GB). Takes a few minutes.

### 2. Configure

```bash
cp .graphrag/config.yaml.example .graphrag/config.yaml
```

Edit `.graphrag/config.yaml`:

```yaml
working_dir: .graphrag/data
embedding_model: intfloat/multilingual-e5-large
embedding_dim: 1024
max_token_size: 512
openrouter_api_key: "your-key-here"
openrouter_model: google/gemma-3-12b-it:free
```

The only required value is `openrouter_api_key`. Get a free key at https://openrouter.ai/keys

Environment variables override config file values:

| Variable | Overrides |
|----------|-----------|
| `GRAPHRAG_WORKING_DIR` | `working_dir` |
| `GRAPHRAG_EMBEDDING_MODEL` | `embedding_model` |
| `OPENROUTER_API_KEY` | `openrouter_api_key` |
| `OPENROUTER_MODEL` | `openrouter_model` |

### 3. Add to Claude Code

Add to `.claude/settings.local.json`:

```json
{
  "mcpServers": {
    "graphrag": {
      "command": "graphrag_mcp/.venv/bin/python3",
      "args": ["-m", "graphrag_mcp.server"],
      "cwd": "/absolute/path/to/knowledge-management-kit"
    }
  }
}
```

Replace `/absolute/path/to/knowledge-management-kit` with the actual project root path.

## Tools

| Tool | Description | Required params | Optional params |
|------|-------------|-----------------|-----------------|
| `insert_kg` | Insert entities, relationships, and text chunks into the knowledge graph. Use at commit time after extracting triples from ADR/docs/sessions. | `custom_kg` (JSON string) | -- |
| `search_knowledge` | Hybrid semantic + graph search across the knowledge base. Returns raw context for Claude to interpret. | `query` (string) | `mode` (naive/local/global/hybrid, default: hybrid), `top_k` (int, default: 60) |
| `delete_by_source` | Delete all entities, relationships, and chunks from a specific source file. Use before re-inserting updated triples. | `source_id` (string, e.g. `meta/decisions/core/CORE-01.md`) | -- |
| `check_entity` | Check if an entity exists in the knowledge graph by canonical name. | `entity_name` (string) | -- |
| `graph_stats` | Return knowledge graph statistics: node count, edge count. | -- | -- |

### insert_kg input format

The `custom_kg` parameter is a JSON string with this structure:

```json
{
  "entities": [
    {
      "entity_name": "FAR Protocol",
      "entity_type": "concept",
      "description": "Proactive semantic context management with HOT/WARM/COLD layers.",
      "source_id": "meta/decisions/core/CORE-01.md"
    }
  ],
  "relationships": [
    {
      "src_id": "FAR Protocol",
      "tgt_id": "sessions.md",
      "description": "WARM residual from FAR audit is written to sessions.md.",
      "keywords": "depends-on, writes-to",
      "weight": 0.9,
      "source_id": "meta/decisions/core/CORE-01.md"
    }
  ],
  "chunks": [
    {
      "content": "FAR Protocol manages context: HOT (active, max 3-5), WARM (archive), COLD (discard).",
      "source_id": "meta/decisions/core/CORE-01.md"
    }
  ]
}
```

## How It Works

**Architecture:** Single Python process. MCP server wraps LightRAG Python SDK directly (no HTTP layer). Claude Code communicates via MCP stdio protocol.

**Embedding:** [FastEmbed](https://github.com/qdrant/fastembed) with `intfloat/multilingual-e5-large` (1024 dimensions). Runs locally, no API calls. Supports multilingual queries (Russian + English work equally well).

**Storage:** [LightRAG](https://github.com/HKUDS/LightRAG) stores the knowledge graph, vector index, and text chunks on disk in `.graphrag/data/`. Uses `insert_custom_kg` to load pre-extracted triples (entities + relationships + chunks) without LLM extraction overhead.

**LLM:** [OpenRouter](https://openrouter.ai/) provides the LLM for entity merge operations (deduplicating entities that refer to the same concept). Uses `google/gemma-3-12b-it:free` by default -- costs nothing. The LLM is only called during merge, not during search.

**Search modes:**
- `naive` -- vector similarity only
- `local` -- entity neighborhood traversal
- `global` -- community-level summaries
- `hybrid` -- combines local + global (default, best quality)

## Testing

```bash
cd graphrag_mcp
source .venv/bin/activate
python3 -m pytest tests/ -v --timeout=300
```

The test suite has 13 tests across 5 files:

| File | Tests | What it covers |
|------|-------|----------------|
| `test_embedding.py` | 2 | Embedding shape (2 texts -> 2x1024), multilingual similarity |
| `test_llm.py` | 2 | LLM returns string, empty key returns empty string |
| `test_bridge.py` | 3 | Insert + search, stats after insert, search on empty graph |
| `test_server.py` | 3 | MCP tool handlers: insert_kg, search, graph_stats |
| `test_e2e.py` | 3 | Russian semantic search, cross-entity connections, full MCP flow |

First run is slow (downloads embedding model). Subsequent runs take ~30-60 seconds.

## File Structure

```
graphrag_mcp/
  __init__.py          # Package marker
  server.py            # MCP server entry point -- tool definitions + handlers
  bridge.py            # LightRAG wrapper (insert/search/delete/stats)
  embedding.py         # FastEmbed wrapper for LightRAG's EmbeddingFunc
  llm.py               # OpenRouter LLM client for entity merge
  config.py            # Config loading from .graphrag/config.yaml + env vars
  requirements.txt     # Dependencies
  tests/
    conftest.py        # Shared fixtures (temp dirs, sample KG)
    test_embedding.py
    test_llm.py
    test_bridge.py
    test_server.py
    test_e2e.py

.graphrag/
  config.yaml.example  # Config template
  config.yaml          # User config (gitignored)
  data/                # LightRAG storage (gitignored, auto-created)
```
