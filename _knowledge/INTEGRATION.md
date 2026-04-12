# Integration — Knowledge Management Kit

> This file is read by Claude during installation. The user gives the prompt:
> "Read _knowledge/INTEGRATION.md and perform the integration. Guide me through the steps."

## Step 0: Git Check

Check: is git initialized in the project?

```bash
git rev-parse --git-dir 2>/dev/null
```

**If git is not initialized (command returned an error):**

Tell the user: "Git is not initialized in the project. The knowledge management system uses git for history tracking and automatic hooks. Initialize? (yes/no)"

If yes:
```bash
git init
```

Before the first commit, check: are there sensitive files (.env, credentials, API keys, large binaries)? If so — create .gitignore first:
```bash
echo ".env" >> .gitignore
echo "*.key" >> .gitignore
echo "*.pem" >> .gitignore
```

Then:
```bash
git add -A
git commit -m "initial commit"
```

If no — warn: "Without git, hooks (Secretary Protocol, context recovery, auto-capture) will not work. The file structure will be installed, but automation will be disabled."

**If git is already initialized** — proceed to Step 1.

## Step 1: Interview

Ask the user (one question at a time):

1. **Project name** — what is the project called? (example: "my-web-app", "trading-bot")
2. **Description** — one sentence: what does the project do? (example: "A web application for task management")
3. **Phase** — what stage is it at? (example: "prototype", "development", "production")
4. **Decision domains** — what are the main areas? (example: "backend, frontend" or "core, api, database"). Minimum 1 domain. Claude can suggest domains based on the description.
5. **Research domains** — what topics for research? (example: "architecture, performance" or ""). Can be skipped.

## Step 2: Check Existing CLAUDE.md

Check: does CLAUDE.md already exist in the project root?

**If it exists:**
- Read it
- Preserve existing content
- In Step 3, merge: add the "Project Model" section from the template, keep existing user rules
- Ask the user: "You already have a CLAUDE.md. I'll merge it with the knowledge management system. OK?"

**If not:**
- Create from scratch using the template

## Step 3: File Generation

Use interview answers to fill in templates.

### 3.1 CLAUDE.md

Read `_knowledge/CLAUDE.md.template`. Replace:
- `{{PROJECT_NAME}}` → project name
- `{{PROJECT_DESCRIPTION}}` → write a brief about the user's project, following the 8 principles from the HTML comment in the template. Don't copy the user's answer verbatim — write an orientation for a new agent.
- `{{PROJECT_PHASE}}` → phase

If CLAUDE.md already exists:
- Insert the "## Project Model" section from the template at the beginning
- Insert sections "## Initialization", "## Rules", "## Knowledge Management", "## FAR Protocol" after
- Keep all existing user sections that are not in the template

Write file: `CLAUDE.md` (to project root)

### 3.2 meta/ Structure

Create directories:
```bash
mkdir -p meta/decisions meta/docs meta/drafts
```

For each decision domain from the interview:
```bash
mkdir -p meta/decisions/{{domain_name}}
```

For each research domain (if specified):
```bash
mkdir -p meta/docs/{{topic_name}}
```

### 3.3 Conflict Check

Before copying, check:

**If `meta/` already exists:** ask the user "Directory meta/ already exists. Can it be used for the knowledge management system? (yes/no)". If no — suggest an alternative name.

**If `.claude/hooks/` already contains files:** show the list of existing files. Ask "Overwrite existing hooks? (yes/no)". If no — skip hook copying and show instructions for manual integration.

### 3.4 Copy Files Without Changes

Copy from `_knowledge/` to the project root:
- `Full Attention Residuals.md` → root
- `agents/AGENT_PROTOCOL.md` → `agents/`
- `meta/roadmap.md` → `meta/`
- `meta/sessions.md` → `meta/`
- `meta/project_manifest.md` → `meta/`
- `meta/drafts/.gitkeep` → `meta/drafts/`
- `.claude/hooks/*` → `.claude/hooks/` (all 7 hooks)
- `.claude/commands/*` → `.claude/commands/` (all 9 commands)
- `.claude/scripts/context.py` → `.claude/scripts/`
- `templates/extraction-template.json` → `templates/`

### 3.5 Index Generation

**meta/_tags.md** — create with domains from the interview:
```markdown
# Tag Dictionary

Shared across meta/decisions/ and meta/docs/. New tag → add here first + justify.

## System
(empty for now — tags will appear with the first decisions)
```

**meta/decisions/_index.md** — hub with domains from the interview:
```markdown
# Decisions Hub
Decisions: 0 | ■ 0 | ◆ 0 | ● 0
Domain indexes: meta/decisions/{domain}/_index.md

Legend: ■ AXIOM | ◆ RULE | ● HYPOTHESIS

## Domains
| Domain | Decisions | Statistics | Description |
|--------|-----------|------------|-------------|
| {{domain1}} | 0 | ■ 0 ◆ 0 ● 0 | {{description1}} |
| {{domain2}} | 0 | ■ 0 ◆ 0 ● 0 | {{description2}} |

## Review Triggers
(empty for now)
```

For each domain — **meta/decisions/{{domain}}/_index.md**:
```markdown
# {{domain}}
Decisions: 0 | ■ 0 | ◆ 0 | ● 0
```

**meta/docs/_index.md** — hub:
```markdown
# Research Map

Rule: before answering a question on a topic — read the file. Don't answer from memory.
Domain indexes: meta/docs/{topic}/_index.md

## Topics
| Topic | Documents | Description |
|-------|-----------|-------------|
```

For each research domain — **meta/docs/{{topic}}/_index.md**:
```markdown
# Documentation: {{topic}}
Documents: 0
```

### 3.6 Hook Configuration (.claude/settings.local.json)

Read `_knowledge/.claude/settings.local.json.template`.

**If `.claude/settings.local.json` already exists:**
- Read it
- Merge: add hooks from the template into the existing "hooks" block. Don't overwrite existing user hooks.
- If a hook with the same event already exists — add ours to the hooks array, don't replace.

**If it doesn't exist:**
- Copy the template as-is, removing ".template" from the name.

### 3.7 .gitignore

Add to `.gitignore` (create if missing):
```
.claude/settings.local.json
.graphrag/data/
.graphrag/config.yaml
meta/drafts/*.md
```

## Step 4: Update Manifest

Fill `meta/project_manifest.md` with the current file structure of the project.

## Step 5: Verification

Check that all files are created BEFORE deleting _knowledge/. If something is missing — inform the user and DO NOT delete _knowledge/.

Output a brief summary:
```
✓ CLAUDE.md — project model + rules
✓ meta/decisions/ — {{N}} domains
✓ meta/docs/ — {{M}} topics
✓ meta/roadmap.md — task stack
✓ meta/sessions.md — session context
✓ meta/drafts/ — auto-capture buffer
✓ .claude/hooks/ — 7 hooks
✓ .claude/commands/ — 9 commands
✓ Full Attention Residuals.md — FAR specification
✓ agents/AGENT_PROTOCOL.md — agent protocol

If all ✓ — proceed to Step 6.
If anything ✗ — inform the user, DO NOT delete _knowledge/, try to fix.
```

## Step 6: Delete _knowledge/

Only after successful verification in Step 5:

```bash
rm -rf _knowledge/
```

Tell the user: "The _knowledge/ folder has been deleted. The system is installed."

```
Next steps:
- Start working. The system is active.
- On the first commit, the Secretary Protocol will trigger.
- For semantic search (optional): /graphrag init
```

## Step 7: GraphRAG (optional)

Ask: "Would you like to connect GraphRAG — semantic search + knowledge graph? (yes/no)"

If yes → "Run `/graphrag init` — it will guide you through the setup."
If no → "You can connect it later with the `/graphrag init` command."
