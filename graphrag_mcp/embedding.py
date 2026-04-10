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
