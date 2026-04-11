# Project Manifest — claude-memory-kit

> Project file structure map. Load on demand.

---

## File Structure

```
claude-memory-kit/
├── CLAUDE.md                        # entry point, initialization
├── Full Attention Residuals.md      # FAR protocol specification
├── README.md                        # user documentation
├── install.sh                       # one-command installer
├── _knowledge/                      # template for installation (copied to target project)
│   ├── INTEGRATION.md               # integration script for Claude
│   ├── CLAUDE.md.template           # CLAUDE.md template
│   └── ...                          # hooks, commands, meta templates
├── agents/
│   └── AGENT_PROTOCOL.md            # agent protocol hub
├── meta/
│   ├── project_manifest.md          # this file (structure map)
│   ├── roadmap.md                   # task stack, statuses
│   ├── sessions.md                  # session context (separate from roadmap)
│   ├── _tags.md                     # shared tag dictionary
│   ├── drafts/                      # auto-capture buffer
│   │   └── .gitkeep
│   ├── decisions/
│   │   ├── _index.md               # decisions hub (domain table)
│   │   ├── core/_index.md          # domain index: system architecture
│   │   └── integration/_index.md   # domain index: installation process
│   └── docs/
│       ├── _index.md               # research hub (topic table)
│       ├── context-management/_index.md
│       └── landscape/_index.md
├── graphrag_mcp/                    # GraphRAG MCP server (optional)
│   ├── server.py                    # MCP entry point
│   ├── bridge.py                    # LightRAG wrapper
│   ├── embedding.py                 # FastEmbed wrapper
│   ├── llm.py                       # OpenRouter client
│   ├── config.py                    # configuration
│   └── tests/                       # 13 tests
├── templates/
│   └── extraction-template.json     # GraphRAG extraction template
├── docs/
│   └── architecture-map.md          # system architecture narrative
└── .claude/
    ├── hooks/
    │   ├── pre-commit-secretary.sh  # PreToolUse: secretary protocol
    │   ├── session-start-recovery.sh # SessionStart: context recovery
    │   ├── session-end-capture.sh   # Stop: auto-capture prompt
    │   ├── pre-compact-handoff.sh   # PreCompact: WARM check
    │   ├── post-compact-reload.sh   # PostCompact: context reload
    │   ├── rebuild-index.sh         # manual: emergency recovery
    │   └── lint-refs.sh             # manual: validation
    ├── commands/
    │   ├── far.md                   # /far (FAR audit)
    │   ├── context.md               # /context (dependency map)
    │   ├── draft.md                 # /draft (session draft)
    │   ├── search.md                # /search (semantic search)
    │   ├── graphrag-extract.md      # /graphrag extract
    │   ├── graphrag-init.md         # /graphrag init
    │   ├── graphrag-reindex.md      # /graphrag reindex
    │   └── knowledge-archaeology.md # /knowledge-archaeology
    ├── scripts/
    │   └── context.py               # dependency graph engine
    └── settings.local.json          # hook configuration
```

<!-- Update this file when adding new directories or significant files -->
