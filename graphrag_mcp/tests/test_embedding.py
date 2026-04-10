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
