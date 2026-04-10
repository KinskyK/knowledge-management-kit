import pytest
import pytest_asyncio
import json
import numpy as np
from lightrag.utils import EmbeddingFunc

from graphrag_mcp.bridge import GraphRAGBridge
from graphrag_mcp.server import GraphRAGServer


# --- Dummy embedding/LLM (random vectors, no real model) ---

async def _dummy_llm(prompt, **kwargs):
    return ""


async def _dummy_embed(texts):
    return np.random.rand(len(texts), 384)


_DUMMY_EMBEDDING = EmbeddingFunc(
    embedding_dim=384,
    max_token_size=512,
    func=_dummy_embed,
)


# --- Realistic KG from the Knowledge Management Kit project ---

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


# --- Fixtures ---

@pytest_asyncio.fixture
async def bridge(tmp_working_dir):
    return await GraphRAGBridge.create(
        working_dir=tmp_working_dir,
        embedding_func=_DUMMY_EMBEDDING,
        llm_func=_dummy_llm,
    )


@pytest_asyncio.fixture
async def server(tmp_working_dir):
    b = await GraphRAGBridge.create(
        working_dir=tmp_working_dir,
        embedding_func=_DUMMY_EMBEDDING,
        llm_func=_dummy_llm,
    )
    return GraphRAGServer(b)


# --- E2E Tests ---

@pytest.mark.asyncio
async def test_e2e_semantic_search_russian(bridge):
    """Insert realistic KG, search in Russian. With dummy embeddings
    we cannot assert semantic relevance, but verify the system works
    end-to-end and returns non-empty results."""
    await bridge.insert_kg(REALISTIC_KG)

    result = await bridge.search(
        "как управлять вниманием в длинной сессии", mode="naive"
    )
    assert isinstance(result, str)
    assert len(result) > 0, "Search returned empty result"


@pytest.mark.asyncio
async def test_e2e_search_finds_connections(bridge):
    """Insert realistic KG, search for dependencies. With dummy embeddings
    we verify the system doesn't crash and returns something."""
    await bridge.insert_kg(REALISTIC_KG)

    result = await bridge.search("what depends on sessions.md", mode="naive")
    assert isinstance(result, str)
    assert len(result) > 0, "Search returned empty result"


@pytest.mark.asyncio
async def test_e2e_full_mcp_flow(server):
    """Full MCP tool flow: insert_kg -> search_knowledge -> graph_stats.
    Uses GraphRAGServer.handle_tool() to test the MCP layer."""
    # Insert via MCP tool
    insert_result = await server.handle_tool(
        "insert_kg", {"custom_kg": json.dumps(REALISTIC_KG)}
    )
    assert "5 entities" in insert_result

    # Search via MCP tool
    search_result = await server.handle_tool(
        "search_knowledge", {"query": "context management layers", "mode": "naive"}
    )
    assert isinstance(search_result, str)
    assert len(search_result) > 0

    # Stats via MCP tool
    stats_result = await server.handle_tool("graph_stats", {})
    stats = json.loads(stats_result)
    assert stats.get("nodes", 0) > 0
