import pytest
import pytest_asyncio
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
async def bridge(tmp_working_dir):
    from graphrag_mcp.bridge import GraphRAGBridge

    return await GraphRAGBridge.create(
        working_dir=tmp_working_dir,
        embedding_func=_DUMMY_EMBEDDING,
        llm_func=_dummy_llm,
    )


@pytest.mark.asyncio
async def test_insert_and_search(bridge, sample_kg):
    await bridge.insert_kg(sample_kg)

    result = await bridge.search("FAR protocol context management", mode="naive")

    assert isinstance(result, str)
    assert len(result) > 0


@pytest.mark.asyncio
async def test_stats_after_insert(bridge, sample_kg):
    await bridge.insert_kg(sample_kg)

    stats = await bridge.stats()

    assert isinstance(stats, dict)
    assert "nodes" in stats
    assert stats["nodes"] >= 2
    assert "edges" in stats
    assert stats["edges"] >= 1


@pytest.mark.asyncio
async def test_search_empty_returns_string(bridge):
    result = await bridge.search("nonexistent query", mode="naive")

    assert isinstance(result, str)
