import json
import asyncio

# These come from the pip 'mcp' package (NOT our graphrag_mcp/)
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

# These come from our package
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
        name="graph_entity",
        description=(
            "Show all connections of a specific entity in the knowledge graph. "
            "Returns: the entity description, all entities it connects to, "
            "and the nature of each connection. Use to explore dependencies "
            "and cross-domain relationships."
        ),
        inputSchema={
            "type": "object",
            "properties": {
                "entity_name": {
                    "type": "string",
                    "description": "Entity name to explore (e.g. 'FAR Protocol', 'CORE-01')",
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
    async def create(
        cls,
        working_dir: str | None = None,
        bridge: GraphRAGBridge | None = None,
    ) -> "GraphRAGServer":
        if bridge:
            return cls(bridge)
        config = load_config()
        if working_dir:
            config.working_dir = working_dir
        bridge = await GraphRAGBridge.create(config=config)
        return cls(bridge)

    async def handle_tool(self, name: str, arguments: dict) -> str:
        if name == "insert_kg":
            kg = json.loads(arguments["custom_kg"])
            result = await self._bridge.insert_kg(kg)
            return (
                f"Inserted: {result['entities']} entities, "
                f"{result['relationships']} relationships, "
                f"{result['chunks']} chunks"
            )

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

        if name == "graph_entity":
            result = await self._bridge.graph_entity(arguments["entity_name"])
            return json.dumps(result, indent=2, ensure_ascii=False)

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
