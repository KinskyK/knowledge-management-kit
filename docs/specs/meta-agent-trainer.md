# Meta-Agent Trainer — Specification

## Purpose

A dedicated agent whose sole mission is continuous improvement of Claude's behavior through reflective analysis of session transcripts. It operates as a "coach watching game footage" — analyzing what happened, extracting behavioral patterns, and writing patches that Claude reads at the next session start.

## Core Principles

1. **Patches at maximum abstraction.** Every behavioral patch must be abstracted to the highest level where it still makes sense. The burden of proof is on narrowing — universal by default.
2. **Full instrument arsenal.** Not just text patches — the trainer selects the optimal tool: patches, rules, skills, hooks, agents, MCP tools, protocol changes.
3. **Two-level self-improvement.** The trainer has its own methodology patches. A clone reviews the trainer's work and updates trainer-patches.
4. **User in control.** Risky changes (CLAUDE.md, hooks) require user confirmation. Every run produces a report.
5. **Both directions.** Learns from mistakes AND successes. Anti-patches protect what works well.

## Architecture

```
Level 0: Main Claude
  reads: behavioral-patches.md (global) + project-specific patches
  works: on tasks in user's projects
  produces: session transcripts (JSONL)

Level 1: Trainer (/improve)
  reads: session transcripts + behavioral-patches.md + trainer-patches.md
  analyzes: mistakes, successes, preferences, knowledge gaps
  produces: updated patches, new skills, improvement-log entries
  then: spawns Level 2

Level 2: Trainer's Clone
  reads: what Level 1 just produced
  analyzes: abstraction quality, instrument choice, conflicts, misses
  produces: updated trainer-patches.md
```

## File Structure

### Global level (~/.claude/)

```
~/.claude/
├── behavioral-patches.md           # Universal patches — read by Claude in ALL projects
├── trainer-patches.md              # Trainer's own methodology — read by /improve
├── improvement-log.md              # History of all changes across projects
└── reflections/                    # Reflections by session
    ├── 2025-04-11-soma-session.md
    └── ...
```

### Project level (meta/)

```
meta/
└── project-patches.md              # Project-specific patches (rare — most should be universal)
```

### Why global, not per-project

Most behavioral patterns are universal: "step outside the frame," "check the full category," "simulate the user's perspective." These improve work in ANY project. Project-specific patches are rare and should be treated as candidates for abstraction.

The trainer lives at `~/.claude/` level and has access to sessions from all projects.

## Trainer Methodology

### Phase 1: Session Analysis

Read session transcripts (JSONL from `~/.claude/projects/`). For each session, identify:

**Corrections:** User said "no," "that's wrong," "you forgot," "explain simpler," "that's not what I meant."
→ What did Claude do wrong? What should it have done?

**Misses:** Claude didn't notice a problem that the user later pointed out. Or Claude proceeded without checking something it should have checked.
→ What signal did Claude miss? What question should it have asked?

**Successes:** User said "exactly," "perfect," "this is what I needed." Or Claude's proposal was accepted without changes.
→ What did Claude do right? What pattern should be preserved?

**Preferences:** User repeatedly asks for a certain style, level of detail, language, approach.
→ What does this user value? How should Claude adapt?

**Knowledge gaps:** Claude didn't know something it needed to know. Not a behavioral issue — a knowledge issue.
→ What knowledge is missing? Where should it be recorded (docs/)?

**Workflow friction:** The process worked but was inefficient — extra steps, slow path to solution.
→ What step was unnecessary? What shortcut was missed?

**Tool misuse/neglect:** Claude used a tool incorrectly or didn't use an available tool.
→ What tool should have been used? Does Claude know about it?

**Context management failures:** Claude lost the thread due to context overflow or attention dilution.
→ Was FAR applied? Was the right information loaded?

Note: these types are examples, not an exhaustive list. The trainer may identify new types of findings.

### Phase 2: Abstraction

For each finding, trace to root behavior through recursive abstraction:

1. What specifically happened? (concrete event)
2. Why? (immediate cause)
3. What behavioral pattern caused this? (class of behavior)
4. Can this be abstracted further without losing meaning? (higher class)
5. Repeat step 4 until the answer is no.
6. The last meaningful level = the patch.

**Abstraction test:** "Does this patch apply to 3+ fundamentally different domains?" If yes — it's at the right level. If it only applies to one domain — abstract further.

**Guard against lazy narrowing:** The default is universal. To classify a patch as project-specific or skill-specific, prove that no useful universal form exists.

**Example abstraction chain:**

```
Event: Claude didn't check _tags.md when creating a new tag #perf
  ↓
Immediate cause: forgot the step in the protocol
  ↓
Behavioral pattern: skipping a verification step when creating an entity
  ↓
Higher class: modifying a system without checking its constraints
  ↓
Even higher: acting without verifying integrity of the context being changed
  ↓
STOP — next level would be "always be careful" (meaning lost)

Patch: Before creating or modifying any entity — verify it satisfies 
the contract of its container.

3-domain test: 
  - tags in _tags.md → check tag dictionary ✓
  - decisions in _index.md → check index contract ✓  
  - code functions → check interface contract ✓
  → PASSES — patch is universal
```

**Counter-example (over-abstracted):**
```
Patch: "Always double-check your work"
3-domain test: passes for everything
BUT: too vague to change behavior in any specific situation → REJECTED
```

The right level = specific enough to trigger a concrete action, abstract enough to apply across domains.

### Phase 3: Instrument Selection

For each improvement, choose the optimal instrument:

| Problem type | Best instrument | Why |
|---|---|---|
| Awareness/mindset | Text patch (behavioral-patches.md) | Changes how Claude thinks |
| Multi-step procedure | Skill (.claude/commands/) | Packages steps into reusable command |
| Reliability (Claude forgets) | Hook + protocol enhancement | Fires automatically |
| Capability (Claude can't) | MCP tool / script | Adds new capability |
| Structural (wrong organization) | CLAUDE.md / AGENT_PROTOCOL change | Changes system structure |
| Communication style | User preference record | Adapts interaction |

**Escalation logic:** If a text patch doesn't work after 3 sessions (evidence: same mistake repeated) → escalate to a stronger instrument (skill, hook, protocol).

### Phase 4: Conflict Check

Before writing any patch:
1. Read all existing patches
2. Check: does the new patch conflict with any existing one?
3. If conflict → resolve: specify contexts where each applies, or merge into one

### Phase 5: Positive Reinforcement

For successes: create anti-patches — "keep doing X, don't change it."

Anti-patch format:
```
KEEP: [behavior that works]
Why it works: [evidence]
Risk if changed: [what could go wrong]
```

Anti-patches protect working behavior from being "optimized away" by future patches.

### Phase 6: Write & Report

1. Write/update patches in behavioral-patches.md
2. Create/update skills if needed
3. Propose changes to CLAUDE.md/hooks (don't apply — wait for user confirmation)
4. Write improvement-log.md entry
5. Generate report for user:
   - What was found (mistakes, successes, preferences)
   - What was changed (patches added/modified/removed)
   - What needs user confirmation (CLAUDE.md/hook changes)
   - Recommendations

### Phase 7: Clone Self-Review

Spawn a clone with prompt:
"Read what the trainer just produced. Evaluate:
- Are patches at maximum abstraction? Apply the 3-domain test.
- Were the right instruments chosen?
- Any conflicts between new and existing patches?
- Anything missed in the session analysis?
- Are trainer-patches.md still relevant and well-calibrated?
Update trainer-patches.md with findings."

## Patch Format

### behavioral-patches.md

```markdown
# Behavioral Patches

Universal rules learned through reflective practice.
Read at every session start. Each patch has evidence trail.

## Active Patches

### P-001: Full category check
Before acting on X — identify the class X belongs to and enumerate other members.
Evidence: reflections/2025-04-11-soma-session.md (missed knowledge types)
Status: active, confirmed effective in 3 sessions

### P-002: Perspective shift
Before evaluating — enumerate all perspectives from which this can be evaluated. Check each.
Evidence: reflections/2025-04-11-soma-session.md (didn't simulate user experience)
Status: active

### P-003: Seam verification  
After verifying parts work — verify the seams between them and emergent behavior of the whole.
Evidence: reflections/2025-04-11-soma-session.md (FAR + auto-capture timing)
Status: active

### KEEP-001: Problem-first narrative
When explaining a system, lead with the problem it solves, not with its components.
Why it works: user consistently responded positively to problem→solution structure
Risk if changed: explanations become abstract and disconnected from motivation

## Archived Patches

(patches moved here when no longer relevant, with reason)
```

### trainer-patches.md

```markdown
# Trainer Methodology Patches

Rules for how the trainer itself should work.

### T-001: Recursive abstraction until boundary
Always attempt one more level of abstraction. Stop only when meaning is lost.
The default is universal. Specificity requires proof (3-domain test fails).

### T-002: Instrument escalation
If a text patch doesn't change behavior after 3 sessions → escalate to stronger instrument.
Don't keep adding text patches for the same problem.

### T-003: Conflict scan before writing
Before any new patch — read all existing patches and check for contradictions.

### T-004: Distinguish behavior from knowledge
"Claude didn't know X" is not a behavioral problem. Don't write a patch.
Instead: identify what knowledge is missing and where to record it.

### T-005: Protect successes
Finding a mistake is not more valuable than finding a success.
Every success deserves a KEEP patch if the behavior is non-obvious.
```

### Reflection format

```markdown
# Reflection: [date] — [project] session

## Findings

### Finding 1: [short name]
Type: mistake | correction | success | preference | knowledge-gap | workflow-friction | tool-misuse | context-management | (other — trainer may define new types)
Event: [what happened — specific quote or description]
Root behavior: [abstract behavioral pattern]
Abstraction chain: [concrete → class → higher class → ... → patch level]
Instrument: [what type of fix is appropriate]
Patch: [the patch text, or reference to skill/hook change]

### Finding 2: ...

## Patch Changes
- Added: P-XXX
- Modified: P-YYY (reason)
- Archived: P-ZZZ (reason)
- KEEP added: KEEP-XXX

## Proposed Changes (need user confirmation)
- [change to CLAUDE.md / hook / etc. — described but not applied]

## Clone Review Notes
- [filled by clone after review]
```

## Triggers

### When to run /improve

**User-initiated:** User runs `/improve` at any time.

**Suggested by session-start hook:** If N sessions have passed since last /improve → suggest:
"N sessions since last improvement review. Consider running /improve."

Configurable N — default 5 sessions.

### What /improve reads

1. `~/.claude/trainer-patches.md` — own methodology
2. `~/.claude/behavioral-patches.md` — current patches
3. Session transcripts from `~/.claude/projects/*/` — last N sessions (default: since last /improve)
4. `~/.claude/improvement-log.md` — history of changes

### What /improve produces

1. Updated `~/.claude/behavioral-patches.md`
2. Updated `~/.claude/improvement-log.md`
3. New reflections in `~/.claude/reflections/`
4. New/updated skills in project's `.claude/commands/` (if needed)
5. Proposed changes for user confirmation
6. Report to user
7. Spawns clone → updated `~/.claude/trainer-patches.md`

## Safety

### Changes that need user confirmation
- Any modification to CLAUDE.md
- Any modification to hooks (.claude/hooks/)
- Any modification to AGENT_PROTOCOL.md
- Creation of new skills that auto-trigger
- Deletion of any existing patch/skill

### Changes that don't need confirmation
- Adding/modifying/archiving patches in behavioral-patches.md
- Adding reflections
- Updating improvement-log.md
- Updating trainer-patches.md (by clone)

### Guardrails
- Trainer cannot delete user's project files
- Trainer cannot modify project source code
- Trainer reports every change with reasoning
- User can revert any change: "undo last /improve"
- Trainer assumes single-user, single-instance execution (no concurrent /improve runs)

## Diminishing Returns

The trainer tracks improvement velocity:
- If last 3 runs found 0 new patches → suggest reducing frequency
- If patches are only being refined (not added) → system is stabilizing
- The trainer can say: "The system is mature. Major improvements unlikely from session analysis alone. Consider running /improve monthly instead of weekly."

Improvement-log rotation: entries older than 6 months are moved to `~/.claude/improvement-log-archive.md`. The active log stays focused on recent changes.

## Self-Viability Assessment

The trainer must regularly evaluate whether it's actually working — not just producing patches, but producing change.

### What to measure

At every /improve run (after run #3), the trainer asks:

**1. Patch effectiveness:** "Of the active patches — do I see evidence that Claude's behavior changed? Specifically: errors that patches were meant to prevent — did they recur or not?"

**2. False positive rate:** "Did any patch cause Claude to behave WORSE? Did the user push back on behavior that a patch introduced?"

**3. Signal vs noise:** "How many of my findings this run are genuinely new vs variations of things I already caught? Am I finding diminishing returns?"

**4. KEEP-patch freshness:** "Are KEEP-patches still protecting relevant behavior, or has the context changed and they're now creating rigidity?"

### Self-report

Every 5 runs, the trainer generates a viability report (in improvement-log.md):

```
## Viability Assessment — run #10

Patches active: 12 | trial: 3 | archived: 4 | KEEP: 5
Confirmed effective (behavior changed): 7 of 12
Uncertain (no opportunity to test): 3 of 12
Possibly ineffective (same errors recurred): 2 of 12
False positives (user pushback): 0
KEEP-patches reviewed: 5, all still relevant

Verdict: system is productive. 58% confirmed effective rate.
Recommendation: continue at current frequency.
```

If confirmed effective rate drops below 30% for 3 consecutive assessments → trainer suggests: "Behavioral patches may not be effective enough as an instrument. Consider: (1) patches are too abstract — try more concrete, (2) patches work but Claude doesn't read them reliably — try hook-based delivery, (3) this approach has fundamental limits — discuss with user."

### Patch accumulation control

Inspired by FAR's HOT-layer principle (max 3-5 items for attention), patches need attention management too:

- At every run, trainer reviews: is behavioral-patches.md becoming a "wall of text"?
- If more than 25 active patches → mandatory consolidation: merge related patches, archive low-evidence ones
- Trainer can propose "patch groups" — thematically related patches combined into a single compound patch
- Anti-entropy rule: every new patch should either replace an existing one or demonstrably add unique value. No accumulation for accumulation's sake.

## Multi-Project Learning

The trainer operates at global level (`~/.claude/`). When analyzing sessions from different projects:

1. Extract findings from each project
2. For each finding — abstract to maximum level
3. If the patch is truly universal (3-domain test) → global behavioral-patches.md
4. If genuinely project-specific (VERY rare) → project's meta/project-patches.md
5. Cross-project patterns: "same mistake in project A and project B" → strong evidence for universal patch

Most patches should be universal. The trainer actively resists project-specific patches by always testing for abstraction.

---

## Appendix A: Session JSONL Format (Audit fix A1)

Session transcripts are stored at `~/.claude/projects/{encoded-path}/{uuid}.jsonl`. The path encoding replaces `/` with `-` and prepends `-` (e.g., `/Users/k/Projects/Soma` → `-Users-k-Projects-Soma`).

Each line is a JSON object. Key types:

| type | What it is | Useful for trainer? |
|------|-----------|-------------------|
| `user` | User message | YES — contains user's words, corrections, questions |
| `assistant` | Claude's response | YES — contains Claude's reasoning, decisions, mistakes |
| `permission-mode` | Session metadata | NO — skip |
| `file-history-snapshot` | File state capture | NO — skip |
| `attachment` | Deferred tools, system messages | RARELY — may contain system context |

**Filtering algorithm:**
1. Read JSONL line by line
2. Keep only `type: "user"` and `type: "assistant"`
3. Extract text content: `message.content` may be a string or array of objects with `type: "text"` and `text` field
4. Skip messages shorter than 30 characters (commands, confirmations)
5. Skip `isSidechain: true` messages (subagent work — not main conversation)

**Discovering project sessions:**
```bash
ls ~/.claude/projects/*/  # list all project directories
# For a specific project, encode its path:
# /Users/k/Projects/Soma → -Users-k-Projects-Soma
ls ~/.claude/projects/-Users-k-Projects-Soma/*.jsonl
```

## Appendix B: Size Strategy (Audit fix A2)

Session files can be very large (5-11MB, 500K-1.3M tokens per session after filtering). Strategy:

**Pre-filtering (before trainer reads):** A bash/python script extracts only user+assistant text messages, skips noise. Output: clean text file ~10-20% of original JSONL size.

**Chunking:** Process one session at a time, not all sessions at once. For each session:
1. Pre-filter to text
2. Split into chunks of 100 message pairs (~30K tokens each)
3. For each chunk: scan for corrections, decisions, successes
4. Write findings per chunk
5. Move to next session

**Priority heuristics:** Not all parts of a session are equally valuable. Prioritize:
- Exchanges containing user corrections ("no," "that's wrong," "you forgot")
- Long back-and-forth discussions (indicate disagreement or complex decision)
- Exchanges near the end of session (often contain summaries)
- Exchanges after topic changes (new decisions likely)

**Token budget per /improve run:** Target ~200K tokens input (fits in Sonnet context). This means: analyze 3-5 sessions with aggressive pre-filtering, or 1 large session in full.

**Model selection:** Phase 1 (session scanning) can use a faster/cheaper model (Sonnet). Phase 2-3 (abstraction, instrument selection) benefit from stronger reasoning (Opus). Phase 7 (clone review) — Sonnet is sufficient.

## Appendix C: Patch Delivery Mechanism (Audit fix E1)

**How patches reach Claude's context:**

Option 1 (recommended): **Global CLAUDE.md**

Create `~/.claude/CLAUDE.md` with:
```markdown
## Behavioral Patches
Read `~/.claude/behavioral-patches.md` at the start of every session. These are rules learned through reflective practice. Follow them.
```

Claude Code reads `~/.claude/CLAUDE.md` for all projects. This is the simplest delivery mechanism.

Option 2: **Global session-start hook**

Add to `~/.claude/settings.json`:
```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "cat ~/.claude/behavioral-patches.md"
      }]
    }]
  }
}
```

This injects patch content at every session start. More reliable than behavioral "read this file" instruction.

Option 3: **Combination** — both global CLAUDE.md (instruction to read) and hook (inject content). Belt and suspenders.

**Testing needed:** Verify that `~/.claude/CLAUDE.md` is actually read by Claude Code in all projects. If not — fall back to hook-based injection.

## Appendix D: Clone Implementation (Audit fix B3)

**Primary approach:** Clone runs as a subagent (Agent tool) from within the trainer's execution. The trainer completes its analysis, then dispatches a review agent with:
- All patches it just wrote/modified
- trainer-patches.md
- Prompt: "Review the trainer's work. Check abstraction level, instrument choice, conflicts, misses. Update trainer-patches.md."

**Fallback if nested agents don't work:** Clone review is a second phase within the same /improve run. After writing patches, the trainer "switches hat" — re-reads its own output and applies trainer-patches.md to critique itself. Less clean separation but technically simpler.

**Alternative fallback:** Separate command `/improve-review` that user runs after `/improve`. Reads the trainer's output and critiques it. More reliable but requires user action.

## Appendix E: Undo Mechanism (Audit fix D1)

Before each /improve run, the trainer creates a backup:

```bash
BACKUP_DIR=~/.claude/backups/$(date +%Y-%m-%d-%H%M%S)
mkdir -p "$BACKUP_DIR"
cp ~/.claude/behavioral-patches.md "$BACKUP_DIR/" 2>/dev/null
cp ~/.claude/trainer-patches.md "$BACKUP_DIR/" 2>/dev/null
cp ~/.claude/improvement-log.md "$BACKUP_DIR/" 2>/dev/null
```

"Undo last /improve" = restore from latest backup:
```bash
LATEST=$(ls -td ~/.claude/backups/*/ | head -1)
cp "$LATEST"/* ~/.claude/
```

## Appendix F: Extended Patch Format (Audit fix F2)

```markdown
### P-001: Full category check
Before acting on X — identify the class X belongs to and enumerate other members.
Created: 2025-04-11
Scope: universal
Evidence: reflections/2025-04-11-soma-session.md
Status: active
```

Fields:
- `Created:` — when the patch was first written
- `Scope:` — `universal` (default) | `when:{condition}` (contextual)
- `Evidence:` — link to reflection that produced it
- `Status:` — `trial` (new, unverified) | `active` (confirmed) | `archived` (moved to archive section)

New patches start as `trial`. After 3 sessions where the patch was relevant and no issues found → `active`. Trainer handles promotion automatically.

## Appendix G: Improvement Log Format (Audit fix A4)

```markdown
# Improvement Log

## 2025-04-11 — /improve run #1
Sessions analyzed: soma (3 sessions), knowledge-management-kit (1 session)
Findings: 5 corrections, 2 successes, 1 preference

### Changes
- Added P-001 (full category check) — trial
- Added P-002 (perspective shift) — trial
- Added KEEP-001 (problem-first narrative) — active
- Proposed: update CLAUDE.md FAR section (pending user confirmation)

### Clone review
- P-001: abstraction OK ✓
- P-002: could abstract further → updated
- trainer-patches.md: added T-006 (check for workflow friction)

## 2025-04-15 — /improve run #2
Sessions analyzed: soma (2 sessions)
Findings: 1 correction (P-001 relevant — worked!), 1 new miss

### Changes
- P-001: trial → active (confirmed in session)
- Added P-004 (failure anticipation) — trial
- Escalated P-003 from text patch to skill /system-audit (3rd session with related miss)
```

## Appendix H: Integration Points (Audit fix E2, E3)

### With FAR Protocol
- Trainer may discover Claude doesn't run FAR audits reliably → patch about attention management, or propose adding FAR-trigger to a hook
- Trainer does NOT modify `Full Attention Residuals.md` directly — that's a specification. Patches adjust behavior around FAR, not FAR itself.

### With Secretary Protocol
- If Claude consistently skips a step → first: text patch reminding about it. If persists → propose strengthening the pre-commit hook check for that step.
- Trainer does not duplicate CLAUDE.md rules in patches. Instead: proposes modifications to CLAUDE.md (with user confirmation).

### With GraphRAG
- Trainer does not interact with GraphRAG directly. But may discover that Claude underuses /search → write patch about when to use semantic search.

### With Auto-capture
- Trainer may discover that auto-capture misses certain knowledge types → propose expanding /draft command or secretary protocol.
- Trainer can also analyze drafts (meta/drafts/) as supplementary material to session transcripts.

### With existing hooks
- Trainer can PROPOSE new hooks or modifications to existing hooks, but changes to hooks require user confirmation.
- The /improve command itself is NOT a hook — it's a manual command (or suggested by session-start hook after N sessions).
