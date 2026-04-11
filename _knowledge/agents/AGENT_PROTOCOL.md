# Agent Network Protocol — claude-memory-kit

> Hub file. Detailed protocols in spoke files. Read during initialization.

---

## Behavioral Principles

- If a decision conflicts with decisions files — say so, with a reference to the decision code.
- First analysis and question, then formulation. Don't propose without being asked.
- Every accepted decision is recorded immediately, not deferred.
- When creating a decision — check against meta/_tags.md (Tag Dictionary).
- During parallel sessions — DO NOT edit meta/ files simultaneously. Conflict → notify the user.
- When closing a block or reconsidering a decision whose code is in the Project Model — check and update the brief in CLAUDE.md.

---

## Built-in Roles

Main Agent switches roles based on conversation context.

| Role | Mandate | Triggers | Output Format |
|---|---|---|---|
| Architect | Decision compatibility, conflict detection | conflict, incompatibility, @architect | CONFLICT → CODES → ESSENCE → OPTIONS → RECOMMENDATION |
| Planner | Block status, dependencies, next step | what's next, status, @planner | COMPLETED → IN PROGRESS → BLOCKED → NEXT STEP |

---

## Decision Recording Protocol

After every accepted decision — immediately:
1. Assign a code (DOMAIN-xx)
2. Record in the appropriate decisions file in ADR format
3. Update _index.md
4. If a new file appeared — update the manifest

ADR format:

**Required fields:**
- **Depends on**: [[codes]]
- **Influences**: [[codes]]
- **Decision**: [what was decided]
- **Why**: [rationale]
- **Reconsider if**: [conditions]
- **Status**: accepted | draft [Axiom | Rule | Hypothesis]

**Recommended sections** (skip only if there's nothing to record):
- **Rejected**: which alternatives were considered and why they were discarded. This is a deep layer — when reconsidering a decision, the agent relies on this section to avoid proposing already-rejected options.

**Optional sections** (added when needed):
- **Context**: what raised the question
- **Evolution vN-1→vN**: what broke in the previous version
- **Example**: scenario
- References to research: based on → docs/...

**Format contract** (for rebuild-index.sh):
- Line 1: `# CODE — name`
- Line 3: `#hashtags` (from meta/_tags.md)
- Field `^- **Status**:` — last occurrence

When modifying an existing decision — overwrite the file, add an "Evolution vN-1→vN" section. Git history stores previous versions.

---

## Triple Extraction Protocol (GraphRAG)

When GraphRAG is present (`/graphrag extract` is available):

After writing/modifying an ADR — extract triples:
1. Entities: decision (code), related concepts, problems, mechanisms
2. Relations: from "Depends on"/"Influences" fields (weight 1.0) + from text (weight 0.7-0.9)
3. Chunks: "Decision" + "Why" + "Rejected" sections

Name canonicity: one entity = one name. "FAR Protocol", not "FAR" / "Full Attention Residuals". Check `check_entity` before creating.

Entity types: decision, concept, problem, domain, mechanism, file.
Relation types: depends-on, influences, solves, part-of, supersedes, rejected, requires, enables, contradicts.

Template: `templates/extraction-template.json`.

---

## Review Trigger Lifecycle

"Reconsider if" triggers live in decisions/_index.md (warning marker).

| Outcome | Action |
|---|---|
| Decision reconsidered | Remove warning from _index. Update file (new version). |
| Decision confirmed | Remove warning from _index. Add to file: "Verified: date, context". |
| Not yet time | Keep warning. |

---

## Spoke File Navigation

Spoke files are created as the project grows. Start with this hub file, extract to spoke when the hub becomes overloaded. Examples of possible spokes:

- agents/pipelines.md — pipelines, HRT, loop-back
- agents/specialists.md — detailed specialist protocols
- agents/context-packages.md — Zone/Specialist load, routing
- agents/verification.md — verification, self-assessment, arbitration
