# Roadmap

## Legend
[ ] not started | [~] started/frozen | [v] active | [x] completed

## Task Stack

### Depth 0

[x] Architecture map document (docs/architecture-map.md)
[x] Sessions deep dive — agent dives into old session blocks
[x] Mandatory "Rejected" section in ADR
[x] Behavioral deep dive triggers
[x] Auto-capture expanded — captures all knowledge types, not just decisions
[x] FAR before COLD — check if knowledge recorded before discarding
[x] docs/ for operational knowledge — rule in CLAUDE.md
[x] /search and /graph rules + MCP tool + commands
[x] Installer (install.sh + _knowledge/ + INTEGRATION.md)
[x] Knowledge archaeology (/knowledge-archaeology command)
[x] All tools connected — every command, hook, script described in CLAUDE.md

### Depth 1

[ ] /system-audit command (six lenses) — defer until 5+ real work sessions
[ ] Meta-agent /improve — spec done (docs/specs/meta-agent-trainer.md), implementation after 5+ sessions
[ ] update.sh — kit version update mechanism for existing users
[ ] VPS deployment for GraphRAG (Web UI in browser)
[ ] GraphRAG triple extraction on Soma — /graphrag extract to populate graph edges (currently 0)

## Session Context
→ meta/sessions.md (separate file; on start, the latest block is loaded)

## Backlog

Observations, gaps, deferred ideas. Periodically review — promote to Task Stack or remove if outdated.

### Observations
- No real-time quality monitoring — blind spot. Observe during real usage first.
- New user first session — wall of rules (111 lines CLAUDE.md, 9-step protocol). Consider progressive disclosure after real user feedback.
- No uninstall path — add before public release.
- 9-step secretary protocol may be unrealistic — consider quick/full commit modes after real usage.
- Claude Code has built-in auto-memory (autoMemoryEnabled, autoDreamEnabled) — monitor how it relates to our system.

### Risks
- Claude Code hook API changes — silent failure. Low probability, high impact.
- CLAUDE.md + behavioral-patches.md context overload — trainer's self-viability assessment monitors this.
- User doesn't commit for days — partially mitigated by session-start staleness check.

### Deferred ideas
- Contradiction detection between decisions (via GraphRAG)
- CLI graph visualization
- Trainer patches may duplicate CLAUDE.md rules — spec says "propose modifications, don't duplicate"
- Trainer is global, GraphRAG is local — acceptable, cross-project learning via text patches
- Archaeology + auto-capture drafts overlap in meta/drafts/ — acceptable, prefixes distinguish them

### Design note
The system started as "~30 files, one prompt." Now: 9 commands, 7 hooks, GraphRAG, trainer spec. Like FAR manages attention in context, the system itself needs attention management: HOT (essential) = CLAUDE.md, ADR, sessions, roadmap, hooks. WARM (power users) = GraphRAG, auto-capture, lint. COLD (defer) = trainer, /system-audit, VPS.
