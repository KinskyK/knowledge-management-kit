# GraphRAG MCP Server Implementation Plan (v2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local MCP server with LightRAG embedded inside it. Claude Code gets semantic search + knowledge graph capabilities. Everything runs on the user's machine — no VPS required for MVP.

**Architecture:** One Python process: MCP server wraps LightRAG Python SDK directly (not through HTTP). `insert_custom_kg` is called as a Python method, not an HTTP endpoint — this is confirmed to work. Embedding via FastEmbed (multilingual-e5-large) runs locally. OpenRouter provides cheap LLM for entity merge. Data stored in `.graphrag/data/` folder on disk.

**Key decision (from audit):** LightRAG REST API does not expose `insert_custom_kg`. But the Python SDK does. By embedding LightRAG inside the MCP server (same process), we call it directly. No HTTP, no missing endpoints.

**Tech Stack:** Python 3.10+, lightrag-hku, fastembed, mcp (Python SDK), httpx (for OpenRouter), numpy

**Plans in this series:**
- **Plan 1 (this):** Local MCP server with LightRAG embedded
- Plan 2: Extraction integration — secretary protocol, triple templates
- Plan 3: Onboarding — commands, README updates
- Future: VPS deployment (move LightRAG to server when needed)

---

## File Structure

```
graphrag_mcp/
├── __init__.py                # Empty, makes graphrag_mcp/ a package
├── server.py                  # MCP server entry point — tool definitions + handlers
├── bridge.py                  # LightRAG initialization + wrapper (insert/search/delete/stats)
├── embedding.py               # FastEmbed wrapper matching LightRAG's EmbeddingFunc signature
├── llm.py                     # OpenRouter LLM client for entity merge
├── config.py                  # Config loading from .graphrag/config.yaml + env vars
├── requirements.txt           # All dependencies
└── tests/
    ├── __init__.py
    ├── conftest.py            # Shared fixtures (temp dirs, sample KG data)
    ├── test_embedding.py      # Embedding function: shape, multilingual quality
    ├── test_bridge.py         # LightRAG bridge: insert, search, delete, stats
    └── test_server.py         # MCP tools: end-to-end through tool handlers

.graphrag/
├── config.yaml                # User config (API keys, model choice)
└── data/                      # LightRAG storage (auto-created, gitignored)
```

**Why this structure:**
- `bridge.py` isolates LightRAG — if we later move to server mode, only bridge changes
- `embedding.py` and `llm.py` are separate because they have different dependencies and can be swapped independently
- Tests mirror source files 1:1

---

### Task 0: Verify insert_custom_kg Works in Python SDK

**Files:** none (verification task)

This is the blocker identified by audit. Before writing any code, confirm the method exists and works.

- [ ] **Step 1: Install LightRAG and verify method exists**

```bash
mkdir -p /tmp/graphrag-verify && cd /tmp/graphrag-verify
python3 -m venv .venv && source .venv/bin/activate
pip install lightrag-hku
python3 -c "from lightrag import LightRAG; print(hasattr(LightRAG, 'insert_custom_kg'))"
```
Expected: `True`

- [ ] **Step 2: Check method signature**

```bash
python3 -c "
from lightrag import LightRAG
import inspect
sig = inspect.signature(LightRAG.insert_custom_kg)
print(f'Signature: {sig}')
print(f'Docstring: {LightRAG.insert_custom_kg.__doc__}')
"
```
Expected: signature showing `custom_kg: dict` parameter. Document the exact signature for use in bridge.py.

- [ ] **Step 3: Minimal smoke test**

```bash
python3 << 'EOF'
import asyncio
from lightrag import LightRAG
from lightrag.utils import EmbeddingFunc
import numpy as np

async def dummy_llm(prompt, **kwargs):
    return ""

async def dummy_embed(texts):
    return np.random.rand(len(texts), 384)

async def main():
    rag = LightRAG(
        working_dir="/tmp/graphrag-verify/data",
        llm_model_func=dummy_llm,
        embedding_func=EmbeddingFunc(
            embedding_dim=384,
            max_token_size=512,
            func=dummy_embed,
        ),
    )
    kg = {
        "entities": [
            {"entity_name": "TestEntity", "entity_type": "concept",
             "description": "A test entity.", "source_id": "test.md"}
        ],
        "relationships": [],
        "chunks": [
            {"content": "Test content.", "source_id": "test.md"}
        ],
    }
    await rag.insert_custom_kg(kg)
    print("insert_custom_kg: OK")

    from lightrag import QueryParam
    result = await rag.aquery(
        "test",
        param=QueryParam(mode="naive", only_need_context=True),
    )
    print(f"query(only_need_context=True): OK, got {type(result)}, length {len(str(result))}")

    # Test 3: insert duplicate entity to trigger merge (tests LLM behavior)
    kg2 = {
        "entities": [
            {"entity_name": "TestEntity", "entity_type": "concept",
             "description": "Updated description of test entity.", "source_id": "test2.md"}
        ],
        "relationships": [],
        "chunks": [],
    }
    try:
        await rag.insert_custom_kg(kg2)
        print("merge with empty LLM: OK (no crash)")
    except Exception as e:
        print(f"merge with empty LLM: FAILED — {e}")
        print("  → Need OpenRouter API key even for merge. Dummy LLM won't work.")

    # Test 4: check if delete_by_entity works
    try:
        await rag.adelete_by_entity("TestEntity")
        print("adelete_by_entity: OK")
    except AttributeError:
        print("adelete_by_entity: NOT FOUND — check method name in this version")
    except Exception as e:
        print(f"adelete_by_entity: FAILED — {e}")

asyncio.run(main())
EOF
```
Expected: Both "OK" lines printed. No errors. This confirms:
1. `insert_custom_kg` works with dummy LLM
2. `aquery(only_need_context=True)` works without calling LLM

- [ ] **Step 4: Clean up**

```bash
rm -rf /tmp/graphrag-verify
```

- [ ] **Step 5: Document results**

If Step 3 succeeded — proceed to Task 1. If it failed — document the error. Common issues:
- Method doesn't exist in this version → check `pip show lightrag-hku` for version, try pinning to latest
- Dummy LLM causes crash → entity merge was triggered. Mitigation: ensure no duplicate entity_name values in test data
- Import error → check if `lightrag` package structure changed

**No commit for this task — it's verification only.**

---

### Task 1: Project Scaffold + Config

**Files:**
- Create: `graphrag_mcp/requirements.txt`
- Create: `graphrag_mcp/__init__.py`
- Create: `graphrag_mcp/config.py`
- Create: `graphrag_mcp/tests/__init__.py`
- Create: `graphrag_mcp/tests/conftest.py`
- Create: `.graphrag/config.yaml.example`
- Modify: `.gitignore`

- [ ] **Step 1: Create requirements.txt**

```
lightrag-hku>=1.4.0,<2.0.0
fastembed>=0.4.0,<1.0.0
mcp>=1.0.0
httpx>=0.27.0,<1.0.0
numpy>=1.24.0
pyyaml>=6.0
pytest>=8.0.0
pytest-asyncio>=0.23.0
```

- [ ] **Step 2: Create empty __init__.py files**

```bash
touch graphrag_mcp/__init__.py graphrag_mcp/tests/__init__.py
```

- [ ] **Step 3: Create config.py**

```python
import os
from dataclasses import dataclass
from pathlib import Path
import yaml


@dataclass
class GraphRAGConfig:
    working_dir: str = ".graphrag/data"
    embedding_model: str = "intfloat/multilingual-e5-large"
    embedding_dim: int = 1024
    max_token_size: int = 512
    openrouter_api_key: str = ""
    openrouter_model: str = "google/gemma-3-12b-it:free"
    openrouter_base_url: str = "https://openrouter.ai/api/v1"


def load_config(config_path: str | None = None) -> GraphRAGConfig:
    config = GraphRAGConfig()

    yaml_path = config_path or os.environ.get(
        "GRAPHRAG_CONFIG", ".graphrag/config.yaml"
    )
    if os.path.exists(yaml_path):
        with open(yaml_path) as f:
            data = yaml.safe_load(f) or {}
        for key, value in data.items():
            if hasattr(config, key):
                setattr(config, key, value)

    env_map = {
        "GRAPHRAG_WORKING_DIR": "working_dir",
        "GRAPHRAG_EMBEDDING_MODEL": "embedding_model",
        "OPENROUTER_API_KEY": "openrouter_api_key",
        "OPENROUTER_MODEL": "openrouter_model",
    }
    for env_key, attr in env_map.items():
        val = os.environ.get(env_key)
        if val:
            setattr(config, attr, val)

    return config
```

- [ ] **Step 4: Create conftest.py**

```python
import pytest
import tempfile
import shutil


@pytest.fixture
def tmp_working_dir():
    d = tempfile.mkdtemp(prefix="graphrag_test_")
    yield d
    shutil.rmtree(d, ignore_errors=True)


@pytest.fixture
def sample_kg():
    return {
        "entities": [
            {
                "entity_name": "FAR Protocol",
                "entity_type": "concept",
                "description": "Proactive semantic context management with HOT/WARM/COLD layers.",
                "source_id": "meta/decisions/core/CORE-01.md",
            },
            {
                "entity_name": "sessions.md",
                "entity_type": "file",
                "description": "Session context storage, separate from roadmap.",
                "source_id": "meta/decisions/core/CORE-02.md",
            },
        ],
        "relationships": [
            {
                "src_id": "FAR Protocol",
                "tgt_id": "sessions.md",
                "description": "WARM residual from FAR audit is written to sessions.md.",
                "keywords": "depends-on, writes-to",
                "weight": 0.9,
                "source_id": "meta/decisions/core/CORE-01.md",
            },
        ],
        "chunks": [
            {
                "content": "FAR Protocol manages context: HOT (active, max 3-5), WARM (archive), COLD (discard).",
                "source_id": "meta/decisions/core/CORE-01.md",
            },
            {
                "content": "Sessions.md stores session context separately from roadmap.",
                "source_id": "meta/decisions/core/CORE-02.md",
            },
        ],
    }
```

- [ ] **Step 5: Create config.yaml.example**

```yaml
# .graphrag/config.yaml — GraphRAG layer configuration
# Copy to .graphrag/config.yaml and fill in values

# Where LightRAG stores its data (graph + vectors + chunks)
working_dir: .graphrag/data

# Embedding model (runs locally, no API needed)
embedding_model: intfloat/multilingual-e5-large
embedding_dim: 1024
max_token_size: 512

# OpenRouter — for entity merge only (rare, pennies/month)
# Get free key at https://openrouter.ai/keys
openrouter_api_key: ""
openrouter_model: google/gemma-3-12b-it:free
```

- [ ] **Step 6: Update .gitignore**

Append to existing `.gitignore`:
```
# GraphRAG
.graphrag/data/
.graphrag/config.yaml
graphrag_mcp/.venv/
graphrag_mcp/__pycache__/
graphrag_mcp/tests/__pycache__/
```

- [ ] **Step 7: Install and verify**

```bash
cd mcp && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
python3 -c "from lightrag import LightRAG; from fastembed import TextEmbedding; print('OK')"
```
Expected: `OK`

- [ ] **Step 8: Commit**

```bash
git add graphrag_mcp/requirements.txt graphrag_mcp/__init__.py graphrag_mcp/config.py graphrag_mcp/tests/__init__.py graphrag_mcp/tests/conftest.py .graphrag/config.yaml.example .gitignore
git commit -m "feat(graphrag): project scaffold — config, fixtures, dependencies"
```

---

### Task 2: Embedding Function

**Files:**
- Create: `graphrag_mcp/embedding.py`
- Create: `graphrag_mcp/tests/test_embedding.py`

- [ ] **Step 1: Write failing tests**

```python
# graphrag_mcp/tests/test_embedding.py
import pytest
import numpy as np


@pytest.mark.asyncio
async def test_embedding_returns_correct_shape():
    from graphrag_mcp.embedding import create_embedding_func

    embed_fn = create_embedding_func("intfloat/multilingual-e5-large")
    result = await embed_fn(["Hello world", "Привет мир"])

    assert isinstance(result, np.ndarray)
    assert result.shape == (2, 1024)


@pytest.mark.asyncio
async def test_similar_texts_are_closer():
    from graphrag_mcp.embedding import create_embedding_func

    embed_fn = create_embedding_func("intfloat/multilingual-e5-large")
    result = await embed_fn([
        "управление контекстом",
        "context management",
        "рецепт борща",
    ])

    def cosine_sim(a, b):
        return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))

    sim_related = cosine_sim(result[0], result[1])
    sim_unrelated = cosine_sim(result[0], result[2])

    assert sim_related > sim_unrelated
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd mcp && source .venv/bin/activate && python3 -m pytest tests/test_embedding.py -v
```
Expected: FAIL — `ModuleNotFoundError`

- [ ] **Step 3: Write embedding.py**

```python
import numpy as np
from fastembed import TextEmbedding
from lightrag.utils import EmbeddingFunc


def create_embedding_func(model_name: str = "intfloat/multilingual-e5-large"):
    model = TextEmbedding(model_name=model_name)

    async def _embed(texts: list[str]) -> np.ndarray:
        return np.array(list(model.embed(texts)))

    return _embed


def create_lightrag_embedding(
    model_name: str = "intfloat/multilingual-e5-large",
    embedding_dim: int = 1024,
    max_token_size: int = 512,
) -> EmbeddingFunc:
    return EmbeddingFunc(
        embedding_dim=embedding_dim,
        max_token_size=max_token_size,
        func=create_embedding_func(model_name),
    )
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
cd mcp && source .venv/bin/activate && python3 -m pytest tests/test_embedding.py -v --timeout=120
```
Expected: 2 PASSED. First run downloads model (~2.2 GB).

- [ ] **Step 5: Commit**

```bash
git add graphrag_mcp/embedding.py graphrag_mcp/tests/test_embedding.py
git commit -m "feat(graphrag): embedding function — FastEmbed multilingual-e5-large"
```

---

### Task 3: OpenRouter LLM Client

**Files:**
- Create: `graphrag_mcp/llm.py`
- Create: `graphrag_mcp/tests/test_llm.py`

- [ ] **Step 1: Write failing test**

```python
# graphrag_mcp/tests/test_llm.py
import pytest
from unittest.mock import AsyncMock, patch


@pytest.mark.asyncio
async def test_llm_returns_string():
    from graphrag_mcp.llm import create_llm_func

    llm_fn = create_llm_func(api_key="test", model="test-model")

    with patch("mcp.llm.httpx.AsyncClient") as MockClient:
        mock_response = AsyncMock()
        mock_response.json.return_value = {
            "choices": [{"message": {"content": "test response"}}]
        }
        mock_response.raise_for_status = lambda: None

        mock_client_instance = AsyncMock()
        mock_client_instance.post.return_value = mock_response
        mock_client_instance.__aenter__ = AsyncMock(return_value=mock_client_instance)
        mock_client_instance.__aexit__ = AsyncMock(return_value=False)
        MockClient.return_value = mock_client_instance

        result = await llm_fn("summarize this")

        assert result == "test response"


@pytest.mark.asyncio
async def test_llm_without_api_key_returns_empty():
    from graphrag_mcp.llm import create_llm_func

    llm_fn = create_llm_func(api_key="", model="test-model")
    result = await llm_fn("anything")

    assert result == ""
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd mcp && source .venv/bin/activate && python3 -m pytest tests/test_llm.py -v
```
Expected: FAIL

- [ ] **Step 3: Write llm.py**

```python
import httpx


def create_llm_func(
    api_key: str = "",
    model: str = "google/gemma-3-12b-it:free",
    base_url: str = "https://openrouter.ai/api/v1",
):
    async def _llm(prompt: str, **kwargs) -> str:
        if not api_key:
            return ""

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model,
                    "messages": [{"role": "user", "content": prompt}],
                },
                timeout=60.0,
            )
            response.raise_for_status()
            return response.json()["choices"][0]["message"]["content"]

    return _llm
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
cd mcp && source .venv/bin/activate && python3 -m pytest tests/test_llm.py -v
```
Expected: 2 PASSED

- [ ] **Step 5: Commit**

```bash
git add graphrag_mcp/llm.py graphrag_mcp/tests/test_llm.py
git commit -m "feat(graphrag): OpenRouter LLM client for entity merge"
```

---

### Task 4: LightRAG Bridge

**Files:**
- Create: `graphrag_mcp/bridge.py`
- Create: `graphrag_mcp/tests/test_bridge.py`

- [ ] **Step 1: Write failing tests**

```python
# graphrag_mcp/tests/test_bridge.py
import pytest


@pytest.mark.asyncio
async def test_insert_and_search(tmp_working_dir, sample_kg):
    from graphrag_mcp.bridge import GraphRAGBridge

    bridge = await GraphRAGBridge.create(working_dir=tmp_working_dir)
    await bridge.insert_kg(sample_kg)

    result = await bridge.search("FAR protocol context management")

    assert isinstance(result, str)
    assert len(result) > 0


@pytest.mark.asyncio
async def test_stats_after_insert(tmp_working_dir, sample_kg):
    from graphrag_mcp.bridge import GraphRAGBridge

    bridge = await GraphRAGBridge.create(working_dir=tmp_working_dir)
    await bridge.insert_kg(sample_kg)

    stats = await bridge.stats()

    assert isinstance(stats, dict)
    assert "entities" in stats or "nodes" in stats


@pytest.mark.asyncio
async def test_search_empty_returns_string(tmp_working_dir):
    from graphrag_mcp.bridge import GraphRAGBridge

    bridge = await GraphRAGBridge.create(working_dir=tmp_working_dir)
    result = await bridge.search("nonexistent query")

    assert isinstance(result, str)
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd mcp && source .venv/bin/activate && python3 -m pytest tests/test_bridge.py -v
```
Expected: FAIL

- [ ] **Step 3: Write bridge.py**

```python
import os
import json
from lightrag import LightRAG, QueryParam
from graphrag_mcp.embedding import create_lightrag_embedding
from graphrag_mcp.llm import create_llm_func
from graphrag_mcp.config import GraphRAGConfig, load_config


class GraphRAGBridge:
    def __init__(self, rag: LightRAG):
        self._rag = rag

    @classmethod
    async def create(
        cls,
        working_dir: str | None = None,
        config: GraphRAGConfig | None = None,
    ) -> "GraphRAGBridge":
        config = config or load_config()
        wd = working_dir or config.working_dir
        os.makedirs(wd, exist_ok=True)

        rag = LightRAG(
            working_dir=wd,
            llm_model_func=create_llm_func(
                api_key=config.openrouter_api_key,
                model=config.openrouter_model,
                base_url=config.openrouter_base_url,
            ),
            embedding_func=create_lightrag_embedding(
                model_name=config.embedding_model,
                embedding_dim=config.embedding_dim,
                max_token_size=config.max_token_size,
            ),
        )
        return cls(rag)

    async def insert_kg(self, custom_kg: dict) -> dict:
        await self._rag.insert_custom_kg(custom_kg)
        return {
            "entities": len(custom_kg.get("entities", [])),
            "relationships": len(custom_kg.get("relationships", [])),
            "chunks": len(custom_kg.get("chunks", [])),
        }

    async def search(
        self, query: str, mode: str = "hybrid", top_k: int = 60
    ) -> str:
        result = await self._rag.aquery(
            query,
            param=QueryParam(mode=mode, only_need_context=True, top_k=top_k),
        )
        if isinstance(result, list):
            return "\n\n---\n\n".join(str(r) for r in result)
        return str(result) if result else ""

    async def delete_by_source(self, source_id: str) -> dict:
        """Delete all entities, relationships, chunks from a specific source file."""
        try:
            # LightRAG stores source_id in entity/relation metadata
            # Try delete_by_entity for entities from this source
            graph = self._rag.chunk_entity_relation_graph
            g = graph._graph if hasattr(graph, "_graph") else graph
            to_delete = [
                n for n in g.nodes()
                if g.nodes[n].get("source_id") == source_id
            ]
            for entity_name in to_delete:
                await self._rag.adelete_by_entity(entity_name)
            return {"deleted_entities": len(to_delete), "source_id": source_id}
        except Exception as e:
            return {"error": str(e), "source_id": source_id}

    async def check_entity(self, entity_name: str) -> dict:
        """Check if an entity exists in the graph."""
        try:
            graph = self._rag.chunk_entity_relation_graph
            g = graph._graph if hasattr(graph, "_graph") else graph
            exists = entity_name in g.nodes()
            return {"entity_name": entity_name, "exists": exists}
        except Exception as e:
            return {"entity_name": entity_name, "exists": False, "error": str(e)}

    async def stats(self) -> dict:
        try:
            graph = self._rag.chunk_entity_relation_graph
            if hasattr(graph, "_graph"):
                g = graph._graph
            else:
                g = graph
            return {
                "nodes": g.number_of_nodes(),
                "edges": g.number_of_edges(),
            }
        except Exception as e:
            return {"error": str(e)}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
cd mcp && source .venv/bin/activate && python3 -m pytest tests/test_bridge.py -v --timeout=180
```
Expected: 3 PASSED. Slow on first run (embedding model).

- [ ] **Step 5: If stats() fails — adjust attribute names**

LightRAG internals may differ by version. Read the error, find the correct attribute:
```bash
python3 -c "
from lightrag import LightRAG
print([a for a in dir(LightRAG) if 'graph' in a.lower()])
"
```
Adjust `stats()` accordingly.

- [ ] **Step 6: Commit**

```bash
git add graphrag_mcp/bridge.py graphrag_mcp/tests/test_bridge.py
git commit -m "feat(graphrag): LightRAG bridge — insert, search, stats"
```

---

### Task 5: MCP Server

**Files:**
- Create: `graphrag_mcp/server.py`
- Create: `graphrag_mcp/tests/test_server.py`

- [ ] **Step 1: Write failing test**

```python
# graphrag_mcp/tests/test_server.py
import pytest
import json


@pytest.mark.asyncio
async def test_insert_kg_tool(tmp_working_dir, sample_kg):
    from graphrag_mcp.server import GraphRAGServer

    srv = await GraphRAGServer.create(working_dir=tmp_working_dir)
    result = await srv.handle_tool("insert_kg", {
        "custom_kg": json.dumps(sample_kg),
    })

    assert "entities" in result.lower() or "inserted" in result.lower()


@pytest.mark.asyncio
async def test_search_tool(tmp_working_dir, sample_kg):
    from graphrag_mcp.server import GraphRAGServer

    srv = await GraphRAGServer.create(working_dir=tmp_working_dir)
    await srv.handle_tool("insert_kg", {"custom_kg": json.dumps(sample_kg)})

    result = await srv.handle_tool("search_knowledge", {"query": "context management"})

    assert isinstance(result, str)
    assert len(result) > 0


@pytest.mark.asyncio
async def test_graph_stats_tool(tmp_working_dir, sample_kg):
    from graphrag_mcp.server import GraphRAGServer

    srv = await GraphRAGServer.create(working_dir=tmp_working_dir)
    await srv.handle_tool("insert_kg", {"custom_kg": json.dumps(sample_kg)})

    result = await srv.handle_tool("graph_stats", {})
    stats = json.loads(result)

    assert "nodes" in stats or "entities" in stats
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd mcp && source .venv/bin/activate && python3 -m pytest tests/test_server.py -v
```
Expected: FAIL

- [ ] **Step 3: Write server.py**

```python
import json
import asyncio
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent
from graphrag_mcp.bridge import GraphRAGBridge
from graphrag_mcp.config import load_config


TOOLS = [
    Tool(
        name="insert_kg",
        description=(
            "Insert entities, relationships and text chunks into the knowledge graph. "
            "Use at commit time after extracting triples from ADR/docs/sessions files. "
            "Input: JSON string with 'entities', 'relationships', 'chunks' arrays."
        ),
        inputSchema={
            "type": "object",
            "properties": {
                "custom_kg": {
                    "type": "string",
                    "description": "JSON with entities, relationships, chunks",
                },
            },
            "required": ["custom_kg"],
        },
    ),
    Tool(
        name="search_knowledge",
        description=(
            "Semantic + graph hybrid search across the knowledge base. "
            "Returns raw context (entities, relationships, text). "
            "Use when navigating by indexes/links is insufficient."
        ),
        inputSchema={
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Natural language query"},
                "mode": {
                    "type": "string",
                    "enum": ["naive", "local", "global", "hybrid"],
                    "default": "hybrid",
                },
                "top_k": {"type": "integer", "default": 60},
            },
            "required": ["query"],
        },
    ),
    Tool(
        name="delete_by_source",
        description=(
            "Delete all entities, relationships and chunks from a specific source file. "
            "Use before re-inserting updated triples for a changed file."
        ),
        inputSchema={
            "type": "object",
            "properties": {
                "source_id": {
                    "type": "string",
                    "description": "Source file path, e.g. meta/decisions/core/CORE-01.md",
                },
            },
            "required": ["source_id"],
        },
    ),
    Tool(
        name="check_entity",
        description="Check if an entity exists in the knowledge graph.",
        inputSchema={
            "type": "object",
            "properties": {
                "entity_name": {
                    "type": "string",
                    "description": "Canonical entity name to check",
                },
            },
            "required": ["entity_name"],
        },
    ),
    Tool(
        name="graph_stats",
        description="Knowledge graph statistics: node count, edge count.",
        inputSchema={"type": "object", "properties": {}},
    ),
]


class GraphRAGServer:
    def __init__(self, bridge: GraphRAGBridge):
        self._bridge = bridge

    @classmethod
    async def create(cls, working_dir: str | None = None) -> "GraphRAGServer":
        config = load_config()
        if working_dir:
            config.working_dir = working_dir
        bridge = await GraphRAGBridge.create(config=config)
        return cls(bridge)

    async def handle_tool(self, name: str, arguments: dict) -> str:
        if name == "insert_kg":
            kg = json.loads(arguments["custom_kg"])
            result = await self._bridge.insert_kg(kg)
            return f"Inserted: {result['entities']} entities, {result['relationships']} relationships, {result['chunks']} chunks"

        if name == "search_knowledge":
            return await self._bridge.search(
                query=arguments["query"],
                mode=arguments.get("mode", "hybrid"),
                top_k=arguments.get("top_k", 60),
            )

        if name == "delete_by_source":
            result = await self._bridge.delete_by_source(arguments["source_id"])
            return json.dumps(result, indent=2)

        if name == "check_entity":
            result = await self._bridge.check_entity(arguments["entity_name"])
            return json.dumps(result, indent=2)

        if name == "graph_stats":
            return json.dumps(await self._bridge.stats(), indent=2)

        raise ValueError(f"Unknown tool: {name}")


async def main():
    srv = await GraphRAGServer.create()
    server = Server("graphrag-mcp")

    @server.list_tools()
    async def list_tools():
        return TOOLS

    @server.call_tool()
    async def call_tool(name: str, arguments: dict):
        result = await srv.handle_tool(name, arguments)
        return [TextContent(type="text", text=result)]

    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream, write_stream, server.create_initialization_options()
        )


if __name__ == "__main__":
    asyncio.run(main())
```

- [ ] **Step 4: Run tests**

```bash
cd mcp && source .venv/bin/activate && python3 -m pytest tests/test_server.py -v --timeout=180
```
Expected: 3 PASSED

- [ ] **Step 5: Smoke test — start server**

```bash
cd mcp && source .venv/bin/activate && python3 -m mcp.server
```
Expected: starts, waits for stdio. Ctrl+C to stop. No errors.

- [ ] **Step 6: Commit**

```bash
git add graphrag_mcp/server.py graphrag_mcp/tests/test_server.py
git commit -m "feat(graphrag): MCP server — 5 tools: insert, search, delete, check, stats"
```

---

### Task 6: End-to-End Test with Realistic Data

**Files:**
- Create: `graphrag_mcp/tests/test_e2e.py`

- [ ] **Step 1: Write E2E test**

```python
# graphrag_mcp/tests/test_e2e.py
import pytest
import json

REALISTIC_KG = {
    "entities": [
        {
            "entity_name": "DSN-001",
            "entity_type": "decision",
            "description": "Three-layer addressing: brief -> roadmap -> /context CODE.",
            "source_id": "meta/decisions/core/DSN-001.md",
        },
        {
            "entity_name": "FAR Protocol",
            "entity_type": "concept",
            "description": "Full Attention Residuals. HOT/WARM/COLD context management.",
            "source_id": "meta/decisions/core/DSN-002.md",
        },
        {
            "entity_name": "sessions.md",
            "entity_type": "file",
            "description": "Session context. Separated from roadmap due to recency bias.",
            "source_id": "meta/decisions/core/DSN-003.md",
        },
        {
            "entity_name": "context window overflow",
            "entity_type": "problem",
            "description": "Claude loses context between sessions and in long sessions.",
            "source_id": "meta/decisions/core/DSN-001.md",
        },
        {
            "entity_name": "secretary protocol",
            "entity_type": "mechanism",
            "description": "Pre-commit checklist: FAR, decisions, indexes, sessions.",
            "source_id": "meta/decisions/core/DSN-004.md",
        },
    ],
    "relationships": [
        {
            "src_id": "DSN-001",
            "tgt_id": "context window overflow",
            "description": "Solves context overflow through structured layers.",
            "keywords": "solves",
            "weight": 1.0,
            "source_id": "meta/decisions/core/DSN-001.md",
        },
        {
            "src_id": "FAR Protocol",
            "tgt_id": "sessions.md",
            "description": "WARM residual written to sessions.md at commit.",
            "keywords": "depends-on, writes-to",
            "weight": 0.9,
            "source_id": "meta/decisions/core/DSN-002.md",
        },
        {
            "src_id": "secretary protocol",
            "tgt_id": "FAR Protocol",
            "description": "Step 1 requires FAR audit.",
            "keywords": "requires",
            "weight": 0.8,
            "source_id": "meta/decisions/core/DSN-004.md",
        },
    ],
    "chunks": [
        {
            "content": "Three-layer addressing: brief (understanding) -> roadmap (navigation) -> /context (details). Lazy loading.",
            "source_id": "meta/decisions/core/DSN-001.md",
        },
        {
            "content": "FAR Protocol: HOT (max 3-5 active) -> WARM (archive, terse) -> COLD (discard). Triggers: phase change, 8-12 exchanges.",
            "source_id": "meta/decisions/core/DSN-002.md",
        },
    ],
}


@pytest.mark.asyncio
async def test_e2e_semantic_search_russian(tmp_working_dir):
    from graphrag_mcp.bridge import GraphRAGBridge

    bridge = await GraphRAGBridge.create(working_dir=tmp_working_dir)
    await bridge.insert_kg(REALISTIC_KG)

    result = await bridge.search("как управлять вниманием в длинной сессии")
    assert len(result) > 0, "Search returned empty result"
    assert any(
        word in result for word in ["FAR", "HOT", "WARM", "context", "attention"]
    ), f"Expected FAR-related content, got: {result[:300]}"


@pytest.mark.asyncio
async def test_e2e_search_finds_connections(tmp_working_dir):
    from graphrag_mcp.bridge import GraphRAGBridge

    bridge = await GraphRAGBridge.create(working_dir=tmp_working_dir)
    await bridge.insert_kg(REALISTIC_KG)

    result = await bridge.search("what depends on sessions.md")
    assert len(result) > 0, "Search returned empty result"


@pytest.mark.asyncio
async def test_e2e_full_mcp_flow(tmp_working_dir):
    from graphrag_mcp.server import GraphRAGServer
    import json

    srv = await GraphRAGServer.create(working_dir=tmp_working_dir)

    insert_result = await srv.handle_tool(
        "insert_kg", {"custom_kg": json.dumps(REALISTIC_KG)}
    )
    assert "5 entities" in insert_result

    search_result = await srv.handle_tool(
        "search_knowledge", {"query": "context management layers"}
    )
    assert len(search_result) > 0

    stats_result = await srv.handle_tool("graph_stats", {})
    stats = json.loads(stats_result)
    assert stats.get("nodes", 0) > 0 or stats.get("entities", 0) > 0
```

- [ ] **Step 2: Run E2E tests**

```bash
cd mcp && source .venv/bin/activate && python3 -m pytest tests/test_e2e.py -v --timeout=300
```
Expected: 3 PASSED. These are slow (embedding model + LightRAG per test).

- [ ] **Step 3: Run full test suite**

```bash
cd mcp && source .venv/bin/activate && python3 -m pytest tests/ -v --timeout=300
```
Expected: All tests PASS (embedding + llm + bridge + server + e2e).

- [ ] **Step 4: Commit**

```bash
git add graphrag_mcp/tests/test_e2e.py
git commit -m "test(graphrag): end-to-end tests with realistic knowledge graph"
```

---

### Task 7: Documentation + Claude Code Config

**Files:**
- Create: `graphrag_mcp/README.md`

- [ ] **Step 1: Write README**

````markdown
# GraphRAG MCP Server

Semantic search + knowledge graph for Knowledge Management Kit.
Runs locally — LightRAG embedded inside MCP server process.

## Setup

### 1. Install

```bash
cd mcp
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

First run downloads embedding model (~2.2 GB). Takes a few minutes.

### 2. Configure

```bash
cp .graphrag/config.yaml.example .graphrag/config.yaml
```

Edit `.graphrag/config.yaml`:
- `openrouter_api_key` — get free key at https://openrouter.ai/keys

### 3. Add to Claude Code

In `.claude/settings.local.json`:
```json
{
  "mcpServers": {
    "graphrag": {
      "command": "graphrag_mcp/.venv/bin/python3",
      "args": ["-m", "mcp.server"],
      "cwd": "/absolute/path/to/project"
    }
  }
}
```

## Tools

| Tool | What it does |
|------|-------------|
| `insert_kg` | Load entities + relationships + text chunks into the graph |
| `search_knowledge` | Hybrid search (graph + vector). Returns raw context for Claude to interpret. |
| `graph_stats` | Node count, edge count |

## Testing

```bash
cd mcp && source .venv/bin/activate
python3 -m pytest tests/ -v --timeout=300
```
````

- [ ] **Step 2: Commit**

```bash
git add graphrag_mcp/README.md
git commit -m "docs(graphrag): MCP server README with setup instructions"
```

---

## Summary

| Task | What | Tests | Key Risk |
|------|------|-------|----------|
| 0 | Verify insert_custom_kg in SDK | smoke test | Blocker if fails |
| 1 | Project scaffold + config | — | — |
| 2 | Embedding function | 2 | Model download ~2.2GB |
| 3 | OpenRouter LLM client | 2 | API key needed for real merge |
| 4 | LightRAG bridge | 3 | Internal API may differ by version |
| 5 | MCP server | 3 | MCP SDK import paths |
| 6 | E2E tests | 3 | Slow, needs all components |
| 7 | Documentation | — | — |

**Total: 8 tasks, 13 tests, 7 commits.**

After this plan: working local MCP server. Claude can insert triples and search the knowledge graph. Next: Plan 2 (extraction templates + secretary protocol integration).
