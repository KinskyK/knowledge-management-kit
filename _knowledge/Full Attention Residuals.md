# Full Attention Residuals (FAR)

**Status:** working specification v0.1

---

## Core Principle

Full Attention Residuals is proactive semantic context management by the model. The model doesn't wait for the context to overflow and be mechanically compressed (/compact), but periodically performs a **semantic audit** — reflecting on what in the context is alive, what is spent, and what is dead.

### Key Difference from /compact

| | /compact (reactive compression) | FAR (proactive audit) |
|---|---|---|
| **When** | On context overflow | Periodically, by triggers |
| **How** | Mechanical compression of everything | Semantic sorting by layers |
| **What's lost** | Unpredictable | Deliberate — only the garbage layer |
| **Horizon** | Backward (what was) | Forward (what will be needed) |
| **Agency** | Passive | Active — the model manages its own attention |

---

## Three Context Layers

### 1. Active Layer (HOT)

> What is needed right now and in the near future.

- Current task and its subtasks
- Open questions awaiting decisions
- Key constraints and requirements
- Unresolved dependencies (what depends on what)

**Marking format:** `[HOT]` — preserve in full.

### 2. Archive Layer (WARM)

> Completed but semantically significant — may be needed for context or retrospective.

- Accepted decisions and their rationale (why X, not Y)
- Results of completed stages (facts, not process)
- Discovered patterns and insights
- Mistakes not worth repeating

**Marking format:** `[WARM]` — compress to bullet points, preserve the essence.

### 3. Garbage Layer (COLD)

> Irrelevant — intermediate steps, exhausted hypotheses, noise.

- Trial attempts that led nowhere
- Intermediate reasoning already embodied in a decision
- Duplicate information
- Technical noise (command output, logs, already processed)

**Marking format:** `[COLD]` — can be safely forgotten.

---

## Audit Triggers

The model initiates a semantic context audit when any of the following conditions occur:

### Automatic Triggers

1. **Work phase change** — transition from research to implementation, from implementation to testing, etc.
2. **Completion of a major subtask** — a logically self-contained block of work is finished.
3. **Context accumulation** — 8-12 exchanges have passed without an audit.
4. **Direction change** — the user switches topics or reconsiders an approach.
5. **Before a complex decision** — the model senses the context is overloaded and impairs clarity.

### Manual Trigger

The user can explicitly request: **"/far"**, **"do a FAR audit"**, or **"perform a semantic audit"**.

---

## Audit Format

When a trigger fires, the model outputs a structured block:

```
## FAR Audit

### [HOT] Active
- <what's currently in focus>
- <open questions>
- <next steps>

### [WARM] Archive
- <key decisions made earlier>
- <results to build upon>

### [COLD] Discard
- <what no longer needs to be kept in mind>

### Horizon
- <what will likely be needed next — anticipation>
```

The **Horizon** section is the key differentiator of FAR from a simple summary. The model not only captures the current state but also predicts what information will become relevant at the next step.

---

## Evaluation Principles

### 1. The query determines significance, not the content itself

The current task/phase is the "query." **Context significance is not absolute but contextual.** The same information can be HOT during debugging and COLD during refactoring. When the work phase changes, a re-audit is necessary.

### 2. Discussion volume ≠ significance

If 10 exchanges were spent on a dead-end branch, that doesn't make it WARM. Evaluate by **semantic value**, not by amount of text.

### 3. HOT — competition for attention

The HOT layer must be **compact**. If too much lands in HOT — attention dilutes and no single element receives sufficient weight. Practical rule: **HOT layer — no more than 3-5 items**.

---

## Blockiness

Exchanges in a dialogue naturally group into semantic blocks:
- **Orientation block** — understanding the task, questions, clarifications
- **Research block** — searching, reading code, analysis
- **Decision block** — choosing an approach, rationale
- **Implementation block** — writing code, testing
- **Reflection block** — evaluating the result, conclusions

FAR audit operates at the block level: a completed block transitions entirely to WARM (compressed to bullet points) or COLD (discarded), rather than each exchange being evaluated individually.

---

## Behavioral Implementation

FAR is not an external tool but a **behavioral protocol**. The model executes it within a regular dialogue:

- **Level 1: Explicit audit** — the model inserts a FAR block in the response at a trigger. The user sees and corrects.
- **Level 2: Silent audit** — the model reviews context "internally" and produces a more focused response.
- **Level 3: Integration** — HOT is captured in TodoWrite, WARM is written to sessions.md.

---

## FAR → sessions.md Link

The WARM residual from a FAR audit = preparatory material for `meta/sessions.md`. On commit: WARM from the latest FAR audit is written to the session block of sessions.md. The FAR audit is a behavioral protocol (in CLAUDE.md); the pre-commit hook REMINDS about it but does not execute it.

---

## Quality Metrics

How to tell that FAR is working:

1. **Coherence** — the model doesn't lose the thread during long sessions
2. **Absence of repetition** — the model doesn't rediscover already-resolved questions
3. **Anticipation accuracy** — the "Horizon" section matches actual developments
4. **Context controllability** — the user can say "go back to X" and the model knows it's a WARM layer
5. **Attention purity** — the model doesn't spend resources on COLD information
