import pytest
import pytest_asyncio
import json
import numpy as np
from lightrag.utils import EmbeddingFunc


async def _dummy_llm(prompt, **kwargs):
    return ""


async def _dummy_embed(texts):
    return np.random.rand(len(texts), 384)


_DUMMY_EMBEDDING = EmbeddingFunc(
    embedding_dim=384,
    max_token_size=512,
    func=_dummy_embed,
)


@pytest_asyncio.fixture
async def server(tmp_working_dir, sample_kg):
    from graphrag_mcp.bridge import GraphRAGBridge
    from graphrag_mcp.server import GraphRAGServer

    bridge = await GraphRAGBridge.create(
        working_dir=tmp_working_dir,
        embedding_func=_DUMMY_EMBEDDING,
        llm_func=_dummy_llm,
    )
    return GraphRAGServer(bridge)


@pytest.mark.asyncio
async def test_insert_kg_tool(server, sample_kg):
    result = await server.handle_tool("insert_kg", {
        "custom_kg": json.dumps(sample_kg),
    })

    assert "entities" in result.lower() or "inserted" in result.lower()


@pytest.mark.asyncio
async def test_search_tool(server, sample_kg):
    await server.handle_tool("insert_kg", {"custom_kg": json.dumps(sample_kg)})

    result = await server.handle_tool("search_knowledge", {"query": "context management"})

    assert isinstance(result, str)
    assert len(result) > 0


@pytest.mark.asyncio
async def test_graph_stats_tool(server, sample_kg):
    await server.handle_tool("insert_kg", {"custom_kg": json.dumps(sample_kg)})

    result = await server.handle_tool("graph_stats", {})
    stats = json.loads(result)

    assert "nodes" in stats or "entities" in stats
