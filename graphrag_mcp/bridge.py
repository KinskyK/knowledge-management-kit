import os

from lightrag import LightRAG, QueryParam
from lightrag.utils import EmbeddingFunc

from graphrag_mcp.config import GraphRAGConfig, load_config
from graphrag_mcp.embedding import create_lightrag_embedding
from graphrag_mcp.llm import create_llm_func


class GraphRAGBridge:
    def __init__(self, rag: LightRAG):
        self._rag = rag

    @classmethod
    async def create(
        cls,
        working_dir: str | None = None,
        config: GraphRAGConfig | None = None,
        embedding_func: EmbeddingFunc | None = None,
        llm_func=None,
    ) -> "GraphRAGBridge":
        config = config or load_config()
        wd = working_dir or config.working_dir
        os.makedirs(wd, exist_ok=True)

        rag = LightRAG(
            working_dir=wd,
            llm_model_func=llm_func or create_llm_func(
                api_key=config.openrouter_api_key,
                model=config.openrouter_model,
                base_url=config.openrouter_base_url,
            ),
            embedding_func=embedding_func or create_lightrag_embedding(
                model_name=config.embedding_model,
                embedding_dim=config.embedding_dim,
                max_token_size=config.max_token_size,
            ),
        )
        await rag.initialize_storages()
        return cls(rag)

    async def insert_kg(self, custom_kg: dict) -> dict:
        await self._rag.ainsert_custom_kg(custom_kg)
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
        """Delete all entities from a specific source file."""
        try:
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
            g = graph._graph if hasattr(graph, "_graph") else graph
            return {
                "nodes": g.number_of_nodes(),
                "edges": g.number_of_edges(),
            }
        except Exception as e:
            return {"error": str(e)}
