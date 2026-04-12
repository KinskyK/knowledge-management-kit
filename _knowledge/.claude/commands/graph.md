Explore connections of an entity in the knowledge graph.

Argument: entity name (e.g. `/graph FAR Protocol`, `/graph CORE-01`, `/graph sessions.md`).

## Instructions

### Step 1: Check GraphRAG availability

If MCP tool `graph_entity` is not available:
- "GraphRAG is not configured. Run `/graphrag init` to set it up."
- Offer alternative: `/context CODE` for decision dependency maps.

### Step 2: Query the graph

Call `graph_entity` with the entity name from $ARGUMENTS.

### Step 3: Present results

If entity found — show:
- Entity type and description
- Source file
- All connections grouped by direction:
  - **Outgoing** (this entity → others): what it depends on, influences, enables
  - **Incoming** (others → this entity): what depends on it, uses it, references it
- For each connection: target/source entity, relationship description, keywords

If entity not found but similar entities exist — show suggestions.

If no connections — "Entity exists but has no connections in the graph. This may mean it was indexed without relationship extraction. Consider running `/graphrag extract` on its source file."

### Step 4: Suggest next steps

Based on connections found:
- "Want to explore [connected entity]? Run `/graph [name]`"
- "Want to search for related knowledge? Run `/search [topic]`"
- "Want to see the decision dependency map? Run `/context [CODE]`"
