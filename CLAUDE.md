# CLAUDE.md — claude-memory-kit

## Project Model
<!-- brief:
Writing principles:
1. This is an orientation for a new agent. After reading, they should understand: what the project is, what the key concepts are, what the constraints are, what's currently in focus.
2. Don't duplicate what's in roadmap or decisions. Brief = "what this is and how to think about it", not "what to do".
3. Structure: essence → key concepts → current state → constraints.
4. Each paragraph answers a question a new agent would have.
5. Update by rewriting sections, not by appending lines. If a section grows — something is redundant.
6. Budget: up to 120 substantive lines. More than that — extract to a separate file.
7. Priority: what directly changes agent behavior > what explains context.
   Only current state, not history. If it doesn't affect actions — don't include it.
8. Style: dense, no filler phrases. Every sentence carries information.
-->

Claude Code loses context between sessions. claude-memory-kit gives it long-term memory: decisions (ADR), tasks (roadmap), research (docs), dependency graph (/context). ~30 files, one prompt to install.

**Architecture.** Three-level addressing: brief (what the project is) → roadmap (what we're doing) → /context CODE (decision details). Two-level indexes: hub `_index.md` (domain table) + domain `{domain}/_index.md` (skeleton). Sessions are separated from roadmap.

**Key mechanisms:**
- FAR (Full Attention Residuals) — proactive context sorting into HOT/WARM/COLD. Specification: `Full Attention Residuals.md`.
- Secretary Protocol — pre-commit checklist: FAR audit, unrecorded decisions, index updates.
- Hooks: pre-commit, session-start, session-end, pre/post-compact, rebuild-index, lint-refs.
- context.py — decision dependency graph parser (forward/reverse/tag search).

**Delivery format.** The `_knowledge/` folder is copied into the target project. INTEGRATION.md is a script for Claude: interview → file generation → project adaptation → `_knowledge/` deletion.

**Phase:** pre-release. The system works, finalization before publication is in progress.

**Constraints:**
- Hooks are specific to Claude Code (settings.local.json). The file structure is universal.
- Git is the only version system. No _archive/.
- CLAUDE.md must not exceed 200 lines. If it grows — extract content.

> Brief = orientation. For working with a specific mechanism — `/context CODE`.

## Initialization
Read before starting work:
1. agents/AGENT_PROTOCOL.md — work protocol and roles
2. meta/roadmap.md — task stack, statuses
3. meta/decisions/_index.md — decisions hub (domain table, counters, triggers)
4. meta/docs/_index.md — research hub (topic table)

Domain indexes: `meta/decisions/{domain}/_index.md` — detailed domain skeleton. Load when the task concerns a specific domain.
manifest (meta/project_manifest.md) — on demand, when the task concerns file structure.
Decision files (meta/decisions/{domain}/{CODE}.md) — load via links from the domain _index when the task concerns them.
backlog (meta/backlog.md) — observations, gaps, deferred ideas. Load when reviewing system health or planning next steps.

**Context commands:**
- `/context CODE` — context map (direct/transitive dependencies, thematic intersections)
- `/context CODE!` — reverse graph (what depends on CODE)
- `/context #tag` — all decisions with this tag
- `/search <query>` — semantic search across all knowledge (decisions + docs). Use when indexes don't find what you need.
- `/graph <entity>` — show all connections of an entity in the knowledge graph
- `/draft` — write a session draft capturing all significant knowledge (decisions, specs, rules, patterns)
- `/knowledge-archaeology` — retroactive extraction from session history + git. Use when a project has history but no documented decisions.
- `/graphrag-init` — set up GraphRAG (semantic search + knowledge graph). Run once per project.
- `/graphrag-extract --changed` — extract triples from changed files into the graph. Used at commit (step 8).
- `/graphrag-reindex` — emergency full rebuild of the knowledge graph from scratch.

**Maintenance commands** (run manually when needed):
- `bash .claude/hooks/rebuild-index.sh` — emergency rebuild of decision/docs indexes from ADR files. Use when indexes are corrupted or out of sync.
- `bash .claude/hooks/lint-refs.sh` — validate referential integrity: [[CODE]] links, ADR format contract, tag sync, orphan files, stale review triggers. Advisory — warns, doesn't block.

**Knowledge graph** (if GraphRAG is configured):
You have a knowledge graph — a network of entities (decisions, concepts, specifications, files) connected by typed relationships (depends-on, influences, solves, part-of, etc.). Two ways to use it: `/search` finds entities by meaning (even if you don't know exact names or domains), `/graph` shows all connections of a specific entity (what depends on it, what it influences, what's nearby). The graph sees cross-domain connections that file-based indexes can't show. Use it as a supplement to index navigation, not a replacement.

**When to use /search** (if GraphRAG is configured):
- Starting work on a topic and not sure if there's relevant knowledge in the base
- Didn't find what you need through indexes — it may be recorded under different words in another domain
- User asks something and you're not sure you know everything — check
- Topic changed mid-session — check if there are decisions and specs for the new topic
- Before recording a new decision — search if a similar one already exists

**When to use /graph:**
- Want to see what's connected to a specific entity (decision, concept, file)
- Exploring dependencies before changing something — what might be affected
- Looking for cross-domain connections that indexes don't show

**Hooks (automatic, you don't call them — know what they do):**
- **session-start**: loads last session block, shows pending drafts, checks uncommitted changes and roadmap staleness
- **session-end (Stop)**: prompts you to write a draft if work was done but no drafts exist
- **pre-commit**: shows secretary protocol checklist, validates indexes and ADR format, checks for missing drafts
- **pre-compact**: checks if WARM was saved to sessions.md. If not — CRITICAL warning. If yes — soft reminder.
- **post-compact**: after compression, re-injects task stack from roadmap + last session block into context

## Rules
- Every accepted decision is recorded immediately in a decisions file in ADR format
- Structural changes (new file, rename) are reflected in the manifest
- Git is the only version system. Manual file versioning is not maintained
- Git commits: when the user says "commit" — Claude does git add, composes a description, and commits + pushes
- Always paraphrase the task before starting work
- When changing decisions or the manifest — verify this file and AGENT_PROTOCOL.md are up to date

## Knowledge Management
- **Secretary Protocol before commit** (steps 0-8):
  0. Are there drafts in meta/drafts/? → read them, formalize decisions in ADR + insights in sessions.md, delete processed ones
  1. Perform FAR audit (WARM → sessions.md)
  2. Are there unrecorded decisions → decisions? (don't forget the "Rejected" section). Decision changes the meaning of something in the Project Model → update brief
  3. Is there unsaved research → docs/?
  4. Update roadmap.md (statuses) + sessions.md (session context)
  5. Review old session blocks → remove absorbed content
  6. Decision with "Reconsider if" → in decisions/_index.md
  7. New/changed accepted file → update domain _index.md + hub _index.md
  8. GraphRAG configured (`.graphrag/config.yaml` exists)? → extract triples from changed files: `/graphrag extract --changed`
- **Project Model (brief)**: updated by rewriting sections, not appending lines. Budget up to 120 substantive lines. If CLAUDE.md > 200 lines → extract brief to a separate file.
- **FAR → sessions.md**: WARM from FAR audit is written to session context (meta/sessions.md)
- **Session Context** (meta/sessions.md): merge blocks, don't overwrite. Each session is a separate block. Block format: `### Session YYYY-MM-DD — brief topic` + keywords in the first line of the body `Topics: topic1, topic2`.
- **Sessions deep dive**: sessions.md is an archive with depth. Don't limit yourself to the last block. Search by keywords in the `Topics:` line.
- **Deep dive triggers** (switching attention to a deep layer):
  - About to change a decision → pay attention to the "Rejected" section in the ADR file (it's already been read — switch your frame to "what was already tried")
  - Discovered a conflict between decisions → search for context in sessions.md by `Topics:`
  - User asks "why not X" / "why exactly this way" → the answer may be in a session block, not in the ADR
  - User raises a topic again that's already in sessions.md → check block headers before diving into bodies
- **"Rejected" section in ADR**: recommended (not optional). Record rejected alternatives and reasons for rejection. This is a deep layer — when reconsidering a decision, it prevents repeating already-rejected options.
- **Auto-capture drafts** (meta/drafts/): when ANY significant knowledge appears — write a draft via `/draft`. Not just decisions: also specifications, business rules, vocabulary, patterns, research findings. Don't wait for commit. This is raw material for the Secretary Protocol.
- **Push heuristic**: loading context for a non-active task → think about push (new Depth in roadmap)
- **docs/**: stores ALL reference knowledge — not just research, but also specifications, business rules, vocabulary, data patterns. Before answering a question on a topic — read the file from docs/. Don't answer from memory. Knowledge discovered → save to docs/. Each file is a living document — update by rewriting (like brief), git stores history.
- **Language rule**: system files (CLAUDE.md, hooks, commands, protocols) — English. User-facing content (ADR content, sessions, roadmap tasks, docs/ content) — user's language of communication.
- **Tags**: when creating a decision — check against meta/_tags.md
- **Backward compatibility**: after any architectural change — go through EVERY existing component (agent, skill, hook, protocol, file) and ask: "does it match the new reality?" Not by categories — one by one. Categories create blind spots.

## FAR Protocol (Full Attention Residuals)
Proactive semantic context management. The `/far` command triggers an audit.

Three layers: **HOT** (active, max 3-5 items) → **WARM** (archive, bullet points) → **COLD** (discard).

Automatic audit triggers:
- Work phase change
- Completion of a major subtask
- 8-12 exchanges without an audit
- Direction change

Specification: `Full Attention Residuals.md`
