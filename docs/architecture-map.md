# How this system came to be

This map tells the story of Knowledge Management Kit — not as a set of components, but as a chain of problems and solutions. Every construct was born from a specific pain point. The order of the narrative follows the order in which the problems arose.

---

## Starting point: context dilution

It all started with a simple observation: in a long session with Claude, information gets diluted. Something gets lost, something gets distorted. The longer the conversation, the worse Claude holds the thread.

From the very beginning, I drew analogies with how people work. A team discusses a problem — noise accumulates, people get confused, they jump between topics. Then a facilitator stops the conversation and takes a snapshot: what's on the agenda, where are we now, what decisions have already been reached. And the invisible part of their work is discarding everything that has already lost relevance from the discussion.

I needed such a facilitator for a session with Claude.

### FAR — session facilitator

That's how FAR (Full Attention Residuals) came about. Initially it was a simple manual cycle: I ran the `/far` command, Claude reviewed the entire context and sorted it into three layers:

- **HOT** — what is needed right now (current task, open questions, next steps). Maximum 3-5 items — more and attention gets diluted.
- **WARM** — processed but valuable (accepted decisions, results, insights). Compressed to bullet points.
- **COLD** — noise (intermediate steps, dead-end branches, processed logs). Safe to forget.

Plus a **Horizon** section — anticipation: what will likely be needed at the next step. This is the key difference from a simple summary: FAR looks not only backward but also forward.

After the audit I ran `clear`, wiped the session, then loaded the compressed context back. Claude continued working with clean, filtered context instead of a mess of hundreds of messages.

The evaluation principle here is important: **context significance is not absolute but contextual**. The same information can be HOT during debugging and COLD during refactoring. And the volume of discussion is not an indicator of significance. If ten exchanges were spent on a dead-end branch, that doesn't make it important.

Audit triggers: phase change, closing a major subtask, 8-12 exchanges without an audit, change of direction. Or manually — `/far`.

> Files: `Full Attention Residuals.md` (specification), `.claude/commands/far.md` (command)

---

## Problem two: loss between sessions

FAR solved the problem within a session. But after a session, only the facilitation results remained — the WARM residual. They are suitable for continuing a local task. But a project is bigger than one task. Different questions are discussed in different sessions. And the WARM from one session may be unsuitable for another.

A general knowledge base level was needed — a place that stores everything that is the product of all past sessions. Not logs (they contain a lot of processed material), but a consolidated result.

### The secretary and decisions

I imagined a secretary who meticulously collects the results of each session. But by what principles should they select the material?

The hypothesis we arrived at: four things matter:
1. **The problem** — what required a decision and why
2. **The decision itself** — what exactly was decided
3. **The rationale** — why this decision was made
4. **Rejected alternatives** — what was not chosen and why

This is essentially the ADR (Architecture Decision Record) format — a methodology invented by Michael Nygard in 2011 for documenting architectural decisions. A classic ADR looks like: number, context, decision, consequences. Simple and effective for development teams.

But the classic ADR was designed for humans who remember context and read files with their eyes. Our system is for an AI that remembers nothing and parses files programmatically. So we adapted the format:

- **Domain codes instead of sequential numbering.** NPC-04 immediately says "fourth decision about NPCs". ADR-0042 says nothing without reading the file.
- **Editability instead of immutability.** A classic ADR is immutable — if a decision is revised, a new ADR is written with a "supersedes" status. In our system, the file is edited in place, with an "Evolution vN→vN+1" section, and git keeps the history.
- **Three confidence levels** instead of proposed/accepted/deprecated: **axiom** (■) — foundation, don't touch; **rule** (◆) — working decision, can be changed with justification; **hypothesis** (●) — being tested, can be changed freely. Without these markers, Claude doesn't distinguish the cost of change — it can suggest "let's redo the entire architecture" just as easily as "let's change the number from 0.20 to 0.18".
- **Explicit links** — `[[NPC-05]]` references between decisions that are parsed by scripts.
- **Machine-readable contract** — line 1 is always `# CODE — name`, line 3 — tags. This allows scripts to parse files automatically.
- **"Reconsider if"** — a built-in trigger. The decision author records at the time of adoption the condition under which it should be reconsidered. A decision is made in a specific context — the context changes, but who will remember that it's time to revisit the decision? The trigger will.
- **"Rejected"** — a recommended (not optional) section. What alternatives were considered and why they were discarded. This is a deep layer of information: when the agent later revisits the decision, this section will prevent proposing already-rejected options. Without it, the ADR stores the winner but not the losers — and the agent can spend years proposing the same "improvement" without knowing it was already considered and rejected.

### Why one file — one decision

This was a deliberate choice among three options:

**One large file** — all decisions in one document. Simple. But with 50+ decisions it's unreadable, git diff is noisy (changed one decision — diff in a 300-line file), lazy loading is impossible (Claude loads everything or nothing), merge conflicts during parallel work.

**Database** (SQLite, JSON) — machine-readable, structured. But Claude can't "read" a database as text, no convenient diff in git, no rendering on GitHub, requires special tools.

**One file = one decision** — the Zettelkasten / Obsidian pattern. Atomic markdown notes connected by links into a graph. This option won:

- Git-friendly — each decision is a separate diff, a separate history
- LLM-friendly — Claude loads one file (~500 tokens) instead of all 56 (~15K). This is the basis of lazy loading
- Human-readable — markdown in any editor, GitHub renders it, Obsidian can open it as a vault and show the link graph
- Linkable — `[[NPC-04]]` in any file creates a reference, from which a knowledge graph emerges
- Scalable — 10 files works, 100 files works, 500 will work

The Obsidian analogy is precise: Obsidian is a tool for humans built on the principle "atomic notes + links = knowledge graph". Our system is the same thing, but for AI.

> Files: `meta/decisions/{domain}/{CODE}.md` (ADR files), `agents/AGENT_PROTOCOL.md` (recording protocol)

---

## Problem three: storage is not yet navigation

The secretary records decisions. But how to navigate them? If there are 5 files, Claude can read them all. If 50 — reading all files will flood the context and create the very noise we were fighting against. A catalog was needed.

### Indexes — an address system

A navigation layer appeared — an index-address system. A new Claude in a new session was something like a librarian in a library: many books, and on the desk lies a catalog where any one can be found.

Two-level structure:
- **Hub** `_index.md` — a domain table: how many decisions, what type, what reconsideration triggers
- **Domain indexes** `{domain}/_index.md` — a skeleton of all domain entries with tags, links, and brief descriptions

Lazy loading: at startup Claude reads only the hub. Domain indexes — when the task concerns a specific domain. The actual decision files — via links from the index. Three levels of depth, each loaded only when needed.

### Roadmap — stack of open questions

Another problem: how to tell what we've already closed, what's still in progress, and what we haven't even touched? When chaotic live work within a session jumps from one topic to another, the agent must be able to return to the stack of questions and restore priorities.

The roadmap leveraged the address system from indexes and tagged questions by status: not started, in progress, completed. With nesting depths — subtasks within tasks.

### Sessions — separating flow from structure

Initially, session context lived inside the roadmap. But three problems emerged:

**Recency bias.** Session blocks accumulated at the bottom of the file. Claude read the file, and fresh session notes (last thing read) pulled attention away from tasks. Tasks got lost.

**Different update frequencies.** Tasks change once every few sessions. The session log — every session. Mixing the stable with the streaming is a path to a file that grows uncontrollably.

**Different readers.** Tasks are needed for "what to do". The session block — for "where we left off yesterday". The session-start hook loads only the latest block — it doesn't need tasks.

We separated them. The roadmap stores tasks. Sessions stores session context — each session adds its own block. Old blocks are reviewed, absorbed content is removed. Git history stores what was deleted.

The session log is the only place where the process lives. Decisions store the result ("decided X because of Y"), but not the path to it ("spent three hours discussing X vs Z, the key insight was W"). The log has three functions:

**Short-term (1-2 sessions):** WARM residual. "Yesterday we stopped at calibration, the output is ready, the analysis hasn't been done yet." The next session starts from context, not from zero. Without this, the first 15 minutes of every session go to "where were we?"

**Medium-term (3-10 sessions):** decision context. If a week later the question "why did we reject option Z?" arises — the answer may be in the session block, not in the ADR (because the ADR recorded only the winner, not all discussions).

**Deep dive.** But this archive had a problem: the agent didn't know it could use it. The session-start hook showed only the latest block. Earlier blocks existed in the file, but the agent didn't know it could dive in there for context. It's like having an archive of meeting minutes but telling no one it exists.

Solution: each session block now has a `Topics:` line with keywords. The session-start hook, when multiple blocks are present, explicitly hints: "there are N more blocks, if something is unclear — read earlier ones". The CLAUDE.md rules state: sessions.md is an archive with depth, don't limit yourself to the last block.

There is no long-term function — old blocks are absorbed by decisions and docs. Absorbed content is removed. Git history stores what was deleted.

### Deep dive triggers — when to dive deeper

The deep layer ("Rejected" section in ADR + old blocks in sessions.md) is a valuable resource. But accessing it for every reason is spending tokens on noise. A balance is needed: don't dive without reason, but don't miss the moment when depth is necessary.

The solution is a behavioral protocol, following the same model as FAR. Not an automatic script, but a set of triggers:

- **Reconsidering a decision.** About to change an existing decision → pay attention to the "Rejected" section in the ADR file. The file has already been read — but "read" and "paid attention to" are not the same thing for a language model. The trigger switches the reading frame: same information, but with the question "what was already tried and why it didn't work" instead of "what did we decide".
- **Conflict between decisions.** A new proposal contradicts an existing one → look for context in sessions.md. Perhaps the old decision was made under different conditions.
- **The "why" question.** The user asks "why not X" or "why exactly this way" → the answer may be in the session block, not in the ADR (the ADR records the winner, not all discussions).
- **Recurring topic.** The user raises a topic that has already come up before → check the block headers in sessions.md before diving into the bodies. If a header matches — read the block body for context.

This is the same principle as in FAR: context significance is contextual. The "Rejected" section can be COLD during normal work and HOT when reconsidering a decision. The trigger switches the significance context.

> Files: `meta/decisions/_index.md` (hub), `meta/decisions/{domain}/_index.md` (domain indexes), `meta/docs/_index.md` (research hub), `meta/roadmap.md`, `meta/sessions.md`

---

## Problem four: a catalog without meaning

Now Claude has a library with a catalog. It can find any "book". But it doesn't understand the meaning of those books, what they're about, or why it needs them. A catalog is an address system, not a meaning map. A new agent in a new session sees indexes as a meaningless table: here are domains, here are counters, here are codes. So what?

### Brief — onboarding into the meaning space

That's how the brief appeared — the "Project model" section in CLAUDE.md. This is not a system description. It's a letter to a new agent: here's what the project is, why it exists, how it's structured, which mechanisms are key, what the constraints are. Budget — up to 120 meaningful lines. One reading — and the agent has a working mental model.

But the brief by itself didn't connect to the catalog. The agent read the letter, understood the project — then opened the index and again didn't understand how to go from understanding to navigation.

The solution was a linkage: the brief references domain addresses directly in the text, and indexes are titled descriptively — filled with meaning, not just codes. The agent reads the brief, sees "domain core — system architecture" with a link to `meta/decisions/core/_index.md`, understands both what's there and why it should go there.

The three-level address model:
1. **Brief** — understanding (what this is, why, how it works)
2. **Hub + roadmap** — navigation (where to go, what's in progress)
3. **Domain index + /context** — details (specific decisions and their connections)

> Files: `CLAUDE.md` ("Project model" section + "Initialization" section)

---

## Problem five: discipline

Everything described above is protocols. FAR, the secretary, updating indexes, recording decisions. But protocols only work if they're followed. Claude is a language model. It won't proactively check indexes before a commit, won't remember the FAR audit after twelve exchanges, won't record WARM before context compression. The system depends on discipline that is easy to break.

### Hooks — automatic reminders

Claude Code hooks attach to lifecycle events. They don't do the work for Claude — they remind and verify. Seven hooks, each solving a specific problem:

**pre-commit-secretary** — triggers before every git commit. Shows the secretary checklist (items 0-8): did you run the FAR audit, are there unrecorded decisions, are indexes updated, is the roadmap updated. Checks for orphan files — decisions that exist as files but are absent from the index. Claude sees the reminder and fixes what was missed before the commit.

**session-start-recovery** — triggers at session start. Checks four things: are there uncommitted changes from the previous session (if so — warns), how fresh is the roadmap (if older than 48 hours — recommends /far), loads the latest block from sessions.md, shows unprocessed drafts from meta/drafts/ (with a warning if older than 7 days). A new session starts with context, not from zero.

**pre-compact-handoff** — triggers before context compression. This is a critical moment: Claude Code automatically compresses history when the context window overflows. Everything that was "in mind" — the current task, intermediate results, contextual understanding — gets compressed to a brief retelling. The hook checks: is the WARM residual recorded in sessions.md? If yes — a gentle reminder to check completeness. If no — CRITICAL: "write it down IMMEDIATELY or you'll lose it".

**post-compact-reload** — triggers after compression. Injects back into Claude's context the task stack from the roadmap and the latest session block from sessions.md. Claude after compression immediately knows: what to do and what it was just working on. The first version was in bash and broke on JSON escaping — rewrote in python.

**rebuild-index** — manual trigger. Emergency recovery: parses all ADR files and rebuilds indexes from scratch. Created as insurance before a major migration (splitting a monolithic 334-line index into hub + 8 domain indexes). The essence of entries (the author's interpretation) is not recovered — it places an honest placeholder "[ESSENCE NOT RECOVERED]". It recovers structure, not meaning.

**lint-refs** — manual trigger. Integrity validation: do all `[[CODE]]` links point to existing files, do tags in files match tags in indexes, is the ADR format contract followed. Advisory mode — warns, doesn't block. Arose from the realization: with dozens of components with cross-references, you rename a file — and all links to it are dead, and nobody notices.

> Files: `.claude/hooks/` (7 scripts)

### Auto-capture drafts — a bridge between work and recording

Protocols work, but depend on Claude's discipline. At the end of a long session, Claude may not remember what was discussed at the beginning. The secretary protocol asks "are there unrecorded decisions?" — but by that point the details (why it was decided, what was rejected) are already blurred.

Auto-capture is a behavioral protocol: upon making a decision, Claude immediately writes a draft to `meta/drafts/`. Not a polished ADR, but raw material: what was decided, why, what was rejected. The `/draft` command.

Four safety nets in case Claude forgets:
- **Stop hook** — session ends: "write a draft if there were discussions"
- **PreCompact hook** — context is being compressed: "write it down before you lose it"
- **Pre-commit hook** — before commit: "any drafts? formalize them. None? write them"
- **Session-start hook** — new session: "there are unprocessed drafts"

Auto-capture and the secretary protocol are different roles. Auto-capture captures raw material (decisions + reasoning). The secretary protocol formalizes (ADR, sessions, indexes). Auto-capture complements FAR: FAR manages attention (what to keep in mind), auto-capture preserves knowledge (what to write down on paper).

---

## Problem six: decisions are a graph

Decisions are not isolated. One can depend on another, influence a third, overlap with a fourth thematically. With 20+ decisions, this dependency graph doesn't fit in one's head.

### /context — connection map

Originally /context was a prompt instruction: "read the index, find the entry, show connections". Claude did this manually — parsing markdown by eye each time. As the system grew, manual parsing became unreliable: Claude missed transitive links, forgot thematic overlaps.

context.py made this deterministic. It parses all domain indexes, builds the graph, ranks results. Three modes:

- `/context CODE` — direct dependencies (1 hop), transitive (2 hop), thematic overlaps (shared tags). Shows specific files to load.
- `/context CODE!` — reverse graph: who depends on this decision. Impact analysis before a change.
- `/context #tag` — all decisions with a tag. A thematic cross-section.

Each call gives the same result — it doesn't depend on how carefully Claude "read" the file.

Tags come from a shared dictionary `_tags.md`. A new tag — first goes into the dictionary with justification. This prevents sprawl: without a dictionary, Claude will create #performance, #perf, #speed for the same thing.

### Agent protocol — uniformity and focus

Without a protocol, Claude records decisions differently every time. In one file — a full ADR with rationale. In another — three lines without "why". In a third — forgot to record it at all.

AGENT_PROTOCOL.md establishes the contract: required fields, line format, the recording procedure. This contract is what context.py, rebuild-index, and lint-refs parse. Without uniformity, the scripts don't work.

The protocol also defines two roles: **Architect** (looks at decision compatibility — "does this new decision conflict with an existing one?") and **Planner** (looks at tasks — "what's next, what's blocked?"). Without explicit roles, Claude does everything simultaneously and nothing deeply. With roles — it switches by context and works with focus.

> Files: `.claude/scripts/context.py`, `.claude/commands/context.md`, `meta/_tags.md`, `agents/AGENT_PROTOCOL.md`

---

## Knowledge archaeology — for projects with history

If a project was already running without a knowledge management system — decisions were made but not recorded. The `/knowledge-archaeology` command goes through the history (Claude Code sessions + git log) and recovers decisions retrospectively.

Four phases: (1) extraction from sessions and git in batches → drafts in meta/drafts/. (2) Grouping by topics, building evolution chains (decision X → changed to Y → expanded to Z). (3) Compilation: at the end of each chain — the current decision → ADR file. Intermediate versions → "Evolution" section, rejected ones → "Rejected". (4) Optional review — the user decides whether to review each ADR or accept all.

This is not a replacement for the secretary protocol — it's a one-time operation for projects that started without documentation.

---

## Overview: system anatomy

```
┌─────────────────────────────────────────────────────┐
│  Dependency graph                                    │
│  /context, tags, agent protocol                      │
│  "How to see connections between decisions"           │
├─────────────────────────────────────────────────────┤
│  Automation                                          │
│  6 hooks: pre-commit, session-start,                 │
│  pre/post-compact, rebuild, lint                     │
│  "How not to forget the process"                     │
├─────────────────────────────────────────────────────┤
│  Semantic navigation                                 │
│  Brief + indexes + roadmap + sessions                │
│  "How to understand and find what's needed"          │
├─────────────────────────────────────────────────────┤
│  Attention management                                │
│  FAR: HOT/WARM/COLD + Horizon                        │
│  "How not to drown in a long session"                │
├─────────────────────────────────────────────────────┤
│  Long-term memory                                    │
│  ADR files (decisions/)                              │
│  "How to remember between sessions"                  │
└─────────────────────────────────────────────────────┘
```

Each layer is needed only when the previous one can no longer cope. A small project with 5 decisions can get by with ADR + brief. The full stack is for projects with dozens of decisions and long sessions.

---

## Three artifact layers in the manual graph

When discussing an automatic knowledge graph (GraphRAG) as an optional system extension, it turned out that the "manual graph" is not a monolith. It has three layers with different natures:

### 1. Authorial assertions about causation

The "Depends on" / "Affects" fields in ADR, the "Reconsider if" section, the "Rejected" section. These are **normative contracts** — the author doesn't describe a discovered connection but establishes an obligation: "if X changes, reconsider Y". Like the difference between "these two laws are thematically related" and "this law references that law" — the second creates a legal consequence.

An automatic graph **cannot replace** this layer — even with perfect model accuracy. It's not about quality: the author decides which connections are normative. The model discovers factual connections but doesn't know which ones should trigger a cascading reconsideration. However, an automatic graph is useful as an **auditor** — "here are connections you didn't record but which exist in the text".

### 2. Authorial curation

Tags (from the dictionary `_tags.md`), domain assignment of decisions, one-line essences in indexes. This is **authorial classification and organization** — a human decides that a decision belongs to domain X and is tagged with Y. rebuild-index places a placeholder "[ESSENCE NOT RECOVERED]" — precisely because the essence is authorial, a script cannot recreate it.

An automatic graph can **supplement** this layer (discover clusters the author didn't see) but not **replace** it — the authorial ontology is part of the decision's meaning.

### 3. Mechanical scaffolding

lint-refs (integrity validation), rebuild-index (emergency recovery), format parsing in context.py, graph traversal. This is service infrastructure.

An automatic graph **replaces** this layer: validation, traversal, visualization — all of this can be done automatically and more reliably.

### GraphRAG summary

GraphRAG (optional extension) is not a replacement for the manual graph, but its augmentation:
- **Replaces** the mechanical scaffolding (layer 3)
- **Supplements** authorial curation (layer 2) — discovers what the author didn't see
- **Doesn't touch** authorial contracts (layer 1) — they remain in ADR files as content

### GraphRAG layer technical architecture

Research (meta/docs/landscape/graphrag-local-stack.md) identified the stack:

**Engine: LightRAG** (the only framework with `insert_custom_kg` — loading a pre-built graph without LLM for extraction). Default storage: JSON + NanoVectorDB + NetworkX, all in a folder on disk.

**Embedding: FastEmbed + multilingual-e5-large** (1024 dimensions, 100+ languages, RU+EN, ONNX without PyTorch). Local, free.

**LLM for graph maintenance: OpenRouter** (Gemma 3 12B free or Qwen3.6 Plus for fractions of a cent). Used only for merging duplicate entities — a rare operation. All heavy lifting (extraction, question answering) — Claude via subscription.

**MCP server: custom** (~100-150 lines of Python). No existing MCP server supports insert_custom_kg. Tools: insert_kg, search_knowledge, delete_source, get_graph_stats.

**Data flow:**
```
On commit:
  Claude (subscription) → extracts triples from changed files
    → standardizes entity names
    → calls MCP: insert_kg(json)
    → LightRAG: insert_custom_kg → embedding → graph + vector

On query:
  Claude (subscription) → calls MCP: search_knowledge(query)
    → LightRAG: hybrid query (graph + vector, only_need_context=True)
    → returns raw context (without LLM synthesis)
    → Claude reads and answers

Cost beyond subscription: ~$0/mo (free OpenRouter model)
                          or ~$0.05/mo (Qwen3.6 Plus)
```

**Extended version installation:**
```bash
pip install lightrag-hku fastembed
# + connect MCP server in Claude Code config
# + set OPENROUTER_API_KEY
```

---

## Data flows

### Session start
```
session-start-recovery hook
  → uncommitted changes? → warn
  → roadmap outdated? → recommend /far
  → load latest block from sessions.md

Claude reads CLAUDE.md
  → brief: project understanding
  → initialization: what to read next
  → as needed: hub → domain index → files
```

### During work
```
FAR audit (auto-trigger or /far)
  → HOT: what's in focus now
  → WARM: what's been processed but is valuable (bullet points)
  → COLD: what to forget
  → Horizon: what will be needed next

Decision made → secretary records
  → ADR file with rationale and links
  → domain _index → hub _index
  → if it changes the project model → update brief
```

### Commit
```
pre-commit-secretary hook
  → secretary checklist (7 items)
  → check: indexes, roadmap, sessions updated?
  → orphan file search
  → Claude fixes what was missed
  → commit
```

### Context compression
```
pre-compact-handoff hook
  → WARM recorded? → gentle reminder
  → WARM NOT recorded? → CRITICAL: write it down now

[compression]

post-compact-reload hook
  → injects task stack + latest session block
  → Claude continues with context
```
