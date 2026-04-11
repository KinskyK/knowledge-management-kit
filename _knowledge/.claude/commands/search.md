Semantic search across the knowledge graph.

Argument: search query in natural language (e.g. "how we handle context overflow").

## Instructions

### Step 1: Check GraphRAG availability

Check if the MCP tool `search_knowledge` is available.

If it is NOT available -- tell the user:

```
GraphRAG is not configured. Run /graphrag init to set it up.
In the meantime, you can search manually:
- /context CODE -- dependency map for a decision
- grep through files in meta/decisions/ and meta/docs/
```

Stop here.

### Step 2: Search

Call the `search_knowledge` MCP tool:

```
search_knowledge(query="$ARGUMENTS", mode="hybrid")
```

### Step 3: Synthesize results

Read the returned context. Provide a useful answer:

- What entities and relationships were found
- How they relate to the query
- Source file paths (so the user can dig deeper)

Group results by relevance. If the query touches multiple topics, organize by topic.

### Step 4: Handle empty results

If the search returned nothing useful:

```
Nothing found for query "$ARGUMENTS".
Try:
- Different phrasing or keywords
- /graphrag reindex -- if files were changed and not indexed
- /context CODE -- direct lookup by decision code
```
