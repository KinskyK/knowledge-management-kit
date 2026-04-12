# Backlog

Observations, gaps, deferred ideas. Not tasks (roadmap) and not decisions (ADR). Things we noticed, wrote down, and will return to.

---

## From self-audit (applying our own patches to the system)

### P-001 gap: No real-time quality monitoring
We cover: knowledge management, context management (FAR), learning (trainer). We don't cover: monitoring whether Claude is spending too much context on reading rules vs actual work. Blind spot.
**Decision:** defer — observe first during real usage on Soma.

### P-002 gap: New user's first session experience
After installation, the user sees CLAUDE.md with 9-step secretary protocol, FAR triggers, deep dive triggers, auto-capture rules. Wall of rules. No gradual onboarding — everything hits at once.
**Decision:** consider a "first session guide" or progressive disclosure — show basic rules first, advanced later. Defer until real user feedback.

### P-002 gap: No uninstall path
Files are spread across the project (meta/, agents/, .claude/, templates/, CLAUDE.md). No way to cleanly remove the kit. Harder to remove than to install.
**Decision:** add uninstall.sh or /uninstall command to backlog. Not urgent — but should exist before public release.

### P-003 gap: Archaeology + auto-capture drafts overlap
Both write to meta/drafts/. Archaeology uses `archaeology-*` prefix, auto-capture uses date prefix. Won't collide on filenames, but secretary protocol processes ALL *.md in drafts/. Could be confusing.
**Decision:** acceptable — prefixes distinguish them. Document the convention.

### P-003 gap: Trainer patches may duplicate CLAUDE.md rules
Trainer writes behavioral-patches.md. CLAUDE.md already has rules. If trainer catches Claude skipping a CLAUDE.md step and writes a patch about it — two places say the same thing. They can drift.
**Decision:** trainer spec says "trainer does not duplicate CLAUDE.md rules, proposes modifications instead." Enforce in trainer-patches.md.

### P-003 gap: Trainer is global, GraphRAG is local
Trainer learns across projects (text patches). GraphRAG stores knowledge per-project (graph). Cross-project insights stay in text, don't flow into project's graph.
**Decision:** acceptable for now. Cross-project learning via text patches is lightweight. GraphRAG indexing of patches is possible future enhancement.

### P-004 risk: Claude Code hook API changes
All 7 hooks depend on specific event names. If Claude Code renames or removes an event — silent failure.
**Decision:** add to lint-refs.sh — verify that hook events in settings.local.json match Claude Code's supported events (if detectable). Defer — low probability, high impact.

### P-004 risk: CLAUDE.md + behavioral-patches.md context overload
More rules = more tokens at session start. CLAUDE.md is 100 lines now but growing. behavioral-patches.md will add more. At some point, reading rules > doing work.
**Decision:** trainer's self-viability assessment monitors this. Also: consider "FAR for rules" — periodic consolidation of CLAUDE.md + patches. Defer until measurable.

### P-004 risk: User doesn't commit for days
Secretary protocol, GraphRAG extraction fire on commit. No commit = no checkpoint. FAR and auto-capture help but are behavioral (unreliable).
**Decision:** consider a periodic reminder (e.g., session-start hook: "no commit in 48+ hours"). Already partially implemented — session-start checks roadmap staleness.

### P-005: Unresolved items from this session

**Not yet implemented (planned):**
1. Expand auto-capture — catch all knowledge types, not just decisions
2. FAR before COLD — check if knowledge is recorded before discarding
3. docs/ for operational knowledge — rule in CLAUDE.md
4. Rules for when to use /search — motivation + algorithm
5. /graph MCP tool — navigate graph connections explicitly
6. Instructions for /graph
7. /system-audit command (six lenses)
8. Meta-agent /improve (spec done, implementation not started)

**Soma-specific:**
9. Update CLAUDE.md description (project is much broader than "financial bot")
10. Integrate knowledge-base.md into docs/ structure
11. System hasn't been used in actual work yet — first real test pending

**Deferred earlier:**
12. update.sh — kit version update mechanism
13. VPS deployment for GraphRAG (Web UI in browser)
14. Contradiction detection between decisions (via GraphRAG)
15. CLI graph visualization
16. Language rule formalization (English for Claude, user's language for content)

---

## System complexity observation

The system started as "20 files, one prompt." Now: ~30 files, 7 hooks, 8 commands, GraphRAG, trainer spec, plans for 8 more changes.

Like FAR manages attention in context, the system itself needs attention management:
- **HOT (essential for basic use):** CLAUDE.md, ADR files, sessions, roadmap, hooks, commands
- **WARM (useful for power users):** GraphRAG, auto-capture, lint, archaeology
- **COLD (defer until needed):** trainer, /system-audit, VPS deployment

Priority: stop building, start using. Real usage on Soma will reveal which features matter and which are theoretical.
