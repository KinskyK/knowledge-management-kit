Retroactive knowledge extraction — read project history and generate ADR files from past decisions.

Use this when a project has history (sessions, git commits) but no documented decisions.

## Overview

Five phases:
1. **Extract** — read history in chunks, write raw drafts
2. **Build evolution trees** — group by topic, trace changes
3. **Compile** — generate ADR files from current state of each decision
4. **Review** — optional user review
5. **Cleanup** — delete processed drafts

## Phase 1: Extract

### Step 1.1: Discover sources

Check what history is available:

**Claude Code sessions:**
```bash
ls ~/.claude/projects/*/  2>/dev/null | head -20
```

Find the project directory that matches the current project path. Session files are `.jsonl` — each line is a JSON record with type "user" or "assistant".

**Git history:**
```bash
git log --oneline --since="6 months ago" | wc -l
```

Tell the user: "Found: N Claude Code sessions, M commits over 6 months. Starting extraction."

If no sessions AND no git history: "No history to analyze. Start working and use the secretary protocol to document decisions."

### Step 1.2: Read sessions in chunks

For each session file (chronologically, oldest first):

Read 50 user+assistant message pairs at a time (one chunk). For each chunk, extract:

- **Decisions**: "decided X", "chose Y", "going with Z", "rejected W"
- **Problems found**: "doesn't work", "broke", "bug", "error" -> what happened and how it was resolved
- **Approach changes**: "used to do X, now Y", "switching to Z"
- **Technical choices**: libraries, architecture, formats, protocols

For each chunk, write a draft to `meta/drafts/`:

Filename: `archaeology-YYYY-MM-DD-NNN.md` where date is from the session and NNN is chunk number.

Format:
```
### Archaeology draft: [session from YYYY-MM-DD, part N]

#### Decisions
- **[Decision]**: [context]. Why: [reason]. Rejected: [what, if mentioned].

#### Problems
- **[Problem]**: [essence] -> [resolution]

#### Approach changes
- **Before:** [X]. **After:** [Y]. **Why:** [reason]
```

Skip chunks that contain only code output, tool results, or routine work without decisions. Write draft only if there's at least one decision, problem, or approach change.

After each session file: report "Session YYYY-MM-DD: N drafts from M parts."

### Step 1.3: Read git history (if no sessions or as supplement)

If session files unavailable or for additional context:

```bash
git log --format="%H %ai %s" --since="6 months ago" --reverse
```

Group commits by week. For each week with significant commits (not just "fix typo"):
- Read commit messages
- For merge commits or large changes: read `git show --stat <hash>` to understand scope
- Extract decisions from commit messages: "migrate to X", "replace Y with Z", "add feature W"

Write drafts in same format, filename: `archaeology-git-YYYY-MM-DD.md`.

### Step 1.4: Report extraction results

"Phase 1 complete. Extracted N drafts from K sessions and M commits."

## Phase 2: Build Evolution Trees

### Step 2.1: Read all archaeology drafts

```bash
ls meta/drafts/archaeology-*.md
```

Read all drafts in chronological order.

### Step 2.2: Group by topic

Identify unique decisions/topics across all drafts. Same decision may appear in multiple drafts with different states:

Example:
- Draft from March: "Decided to store data in a single file"
- Draft from April: "Switched to separate files -- single file became too large"
- Draft from May: "Added two-level indexes on top of separate files"

This is ONE topic with THREE states → evolution chain.

Group into topics. For each topic, build chronological chain:
```
Topic: "Data storage format"
v1 (March): single file
v2 (April): separate files -> v1 rejected (file too large)
v3 (May): separate files + indexes -> v2 extended
Current: v3
```

### Step 2.3: Identify current state

For each topic, the last entry in the chain is the current decision. Earlier entries are history (Evolution) and rejected alternatives (Rejected).

Write consolidated file: `meta/drafts/archaeology-consolidated.md` with all topics and their evolution chains.

Report: "Phase 2 complete. Found N unique decisions, M of which went through evolution."

## Phase 3: Compile ADR Files

### Step 3.1: Ask about domains

"Before generating ADRs: which decision domains should be used?"

If `meta/decisions/` already has domain directories — use them.
If not — suggest domains based on topics found. Ask user to confirm.

Create domain directories if needed:
```bash
mkdir -p meta/decisions/{{domain}}
```

### Step 3.2: Generate ADR files

For each unique current decision, create an ADR file in the appropriate domain:

Filename: `meta/decisions/{{domain}}/{{CODE}}.md`

Code assignment: `{{DOMAIN_PREFIX}}-01`, `{{DOMAIN_PREFIX}}-02`, etc. Uppercase prefix from domain name (e.g., domain "core" → CORE-01).

ADR format (from AGENT_PROTOCOL.md):
```
# {{CODE}} — {{title}}

#{{tags}}

- **Depends on**: [[codes]] (if dependencies found in history)
- **Influences**: [[codes]] (if impacts found)
- **Decision**: [current state -- v3 from evolution chain]
- **Why**: [rationale from history]
- **Reconsider if**: [conditions, if obvious from context]
- **Status**: accepted ◆ RULE

**Rejected:**
- [v1/v2 from evolution chain -- what was tried and why it was abandoned]

**Evolution v1->vN:**
- v1 (date): [what it was]
- v2 (date): [what changed and why]
- ...current
```

If the decision never changed (no evolution): skip Evolution section, include Rejected only if alternatives were discussed.

### Step 3.3: Update indexes

For each domain with new ADR files:
- Update `meta/decisions/{{domain}}/_index.md` — add entries
- Update `meta/decisions/_index.md` (hub) — update counts

Update `meta/_tags.md` if new tags were created.

### Step 3.4: Report

"Phase 3 complete. Generated N ADR files in M domains."

## Phase 4: Optional Review

### Step 4.1: Ask user

"Generated N decisions. Want to review each one? (yes -- I'll show them one by one, no -- all done, you can review them in meta/decisions/)"

### Step 4.2: If yes — review each

For each ADR file:
- Show content
- Ask: "Correct? (yes / fix / delete)"
- If "fix" -- ask what to change, update file
- If "delete" -- remove file, update index

### Step 4.3: If no — done

"All files saved in meta/decisions/. Review at your convenience."

## Phase 5: Cleanup

Delete processed archaeology drafts:
```bash
rm meta/drafts/archaeology-*.md
```

Keep meta/drafts/archaeology-consolidated.md as reference (or delete if user prefers).

Report final: "Archaeology complete. N decisions documented. Knowledge management system is ready."

If GraphRAG configured: "Run `/graphrag extract --changed` to index the new ADRs into the knowledge graph."
