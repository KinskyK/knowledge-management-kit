# Roadmap

## Legend
[ ] not started | [~] started/frozen | [v] active | [x] completed

## Task Stack

### Depth 0

[v] Architecture map document (docs/architecture-map.md) — living document, updated with each new construct
[x] Sessions deep dive — teach the agent to dive into old session blocks when there's a misunderstanding or dispute about the context of a decision
[x] Mandatory "Rejected" section in ADR — each decision stores rejected alternatives and reasons for rejection
[x] Behavioral deep dive triggers — protocol for switching attention to the deep layer during review, conflict, or "why" questions
### Depth 1 — GraphRAG Layer (optional)

Stack: LightRAG (insert_custom_kg + hybrid query) + FastEmbed (multilingual-e5-large) + OpenRouter (Gemma 3 12B / Qwen3.6 Plus for merge). Research: meta/docs/landscape/graphrag-local-stack.md

[ ] MCP server (~100-150 lines Python): insert_kg, search_knowledge, delete_source, get_graph_stats
[ ] Integration of extraction into the Secretary Protocol: Claude extracts triples on commit → insert_custom_kg
[ ] Extraction template: standardize entity types (decision, concept, problem, domain, mechanism) and relationship types
[ ] Query integration: /search command via MCP → LightRAG hybrid query (only_need_context=True) → Claude synthesizes the answer
[ ] Testing: dummy LLM vs OpenRouter, multilingual-e5-large quality on RU+EN, latency at 500 docs

## Session Context
→ meta/sessions.md (separate file; on start, the latest block is loaded)
