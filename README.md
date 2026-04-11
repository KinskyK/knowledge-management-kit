# Knowledge Management System for Claude Code

## What is this

A knowledge management system for projects using Claude Code. Claude records decisions, maintains a task stack, saves research, passes context between sessions, and manages its own attention. ~30 files.

More about each component in the "How it works" section below.

## Installation

### Method 1: One prompt (recommended)

Open Claude Code in your project folder and paste:

```
Download and install the Knowledge Management Kit:
bash -c "$(curl -fsSL https://raw.githubusercontent.com/KinskyK/knowledge-management-kit/main/install.sh)"
Then read _knowledge/INTEGRATION.md and perform the integration. Guide me through the steps.
```

Claude will download the system, ask about your project, and set everything up automatically.

### Method 2: Manual installation

```bash
# Download the template
curl -fsSL https://raw.githubusercontent.com/KinskyK/knowledge-management-kit/main/install.sh | bash

# Open Claude Code and paste the prompt:
# There is a _knowledge/ folder in the project root. Read _knowledge/INTEGRATION.md and perform the integration.
```

### What will happen

Claude will:
- Ask about the project (name, description, phase, domains)
- Check if CLAUDE.md already exists and merge it — or create a new one
- Create directories and set up hooks
- Delete the `_knowledge/` folder after completion

You just answer questions and confirm.

---

## How it works

### The problem

Claude Code remembers nothing between sessions. Every time you start from scratch: what was decided, why, what's in progress — everything is lost. In long sessions it forgets the beginning of the conversation. Decisions drown in noise.

### What the system does

1. **Project Model (CLAUDE.md brief)** — the "Project Model" section in CLAUDE.md gives a new agent a working mental model in a single read. An HTML comment with writing principles ensures quality during updates. Three-level addressing model: brief (understanding) → roadmap (navigation) → index (/context CODE — details).

2. **Decisions (decisions/)** — each decision is recorded in a separate file with rationale, dependencies, and review conditions. Two-level indexes: hub `_index.md` (domain table) + domain `{domain}/_index.md` (detailed skeleton). The `/context CODE` command builds a dependency map.

3. **Task Stack (roadmap.md)** + **Session Context (sessions.md)** — tasks with nesting depth in roadmap. Session log in a separate file. At the end of a session Claude writes the WARM residual to sessions.md — what was done, what's important, keywords for search. Sessions.md is an archive with depth: when there's a misunderstanding, the agent can dive into earlier blocks. The next session doesn't start from zero.

4. **Research (docs/)** — did research → file. Next time Claude reads the file instead of answering from memory.

5. **Attention Management (FAR)** — Claude periodically sorts context into HOT (needed now, max 3-5) / WARM (might be useful, bullet points) / COLD (garbage, forget). The `/far` command triggers it manually.

6. **Hooks** — 7 hooks: pre-commit (secretary checklist), session-start (context recovery), session-end (auto-capture drafts), pre/post-compact (handoff during compression), rebuild-index (emergency recovery), lint-refs (link and contract validation).

### Key principles

- **Git is the only version system.** No _archive/. Need an old version → `git log`.
- **Lazy loading.** At startup — only indexes. Files — via links, when needed.
- **Every decision — immediately.** Decided → file → index. Not "I'll record it later."
- **HOT is compact.** More than 5 things in focus — attention dilutes.

### FAQ

**Do I need Claude Code Pro/Max?** No. Works with any plan.

**Project is already underway, decisions weren't documented?** Run `/knowledge-archaeology` — Claude will go through session history and git, find decisions and generate ADR files.

**Can I skip agents?** Yes. `agents/AGENT_PROTOCOL.md` is optional.

**Works with other LLMs?** Hooks are specific to Claude Code. The file structure is universal.

---

## GraphRAG — semantic search + knowledge graph (optional)

As a project grows, index-based navigation may miss implicit connections. GraphRAG adds:

- **Semantic search** — "how did we solve the context problem" finds the FAR protocol, even if the word "FAR" isn't in the query
- **Knowledge graph** — automatically discovers connections between decisions
- **Combined search** — searches simultaneously by meaning and by graph connections

### Installation

In Claude Code in the project folder:

```
/graphrag init
```

Claude will install dependencies, ask for an OpenRouter API key (free) and index existing files.

### Usage

- `/search <query>` — semantic search in the knowledge graph
- `/graphrag extract --changed` — extract triples from changed files (automatic on commit)
- `/graphrag reindex` — rebuild the graph from scratch

### Cost

- Embedding model: local, free
- OpenRouter (graph maintenance): free (Gemma 3) or ~$0.05/month
- No VPS needed — everything runs on your computer
