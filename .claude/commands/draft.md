Write a session draft capturing decisions, reasoning, and open questions.

Argument: optional topic (e.g. `/draft GraphRAG architecture`). No argument = capture everything from current session.

## Instructions

### Step 1: Review session

Look through the conversation. Identify:

- **Decisions:** What decided? WHY? What alternatives considered? Why rejected?
- **Problems:** What broke? Root cause? Resolution?
- **Approach changes:** Changed direction? From what to what? Why?
- **Open questions:** What unresolved? What needs investigation?

### Step 2: Write draft

Create file: `meta/drafts/YYYY-MM-DD-HHMMSS-topic.md`

Format:

```
### Draft: [topic]
Date: YYYY-MM-DD HH:MM

#### Decisions
- **[What was decided]**: [why]. Rejected: [what and why].

#### Problems
- **[Problem]**: [cause] -> [resolution]

#### Approach changes
- **Before:** [old approach]. **After:** [new]. **Why:** [reason]

#### Open questions
- [question]
```

### Step 3: Confirm

Report: "Draft saved: meta/drafts/[filename]. N decisions, M problems, K questions."
