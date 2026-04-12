Write a session draft capturing ALL significant knowledge — not just decisions.

Argument: optional topic (e.g. `/draft GraphRAG architecture`). No argument = capture everything from current session.

## Instructions

### Step 1: Review session

Look through the conversation. Identify ALL types of valuable knowledge:

- **Decisions:** What decided? WHY? What alternatives considered? Why rejected?
- **Specifications:** Database fields, API contracts, data formats, schemas discussed?
- **Business rules:** Pricing logic, salary calculations, workflows, constraints?
- **Vocabulary:** Domain terms, abbreviations, naming conventions defined?
- **Patterns:** Real data examples, typical scenarios, message formats?
- **Problems:** What broke? Root cause? Resolution?
- **Approach changes:** Changed direction? From what to what? Why?
- **Research findings:** Technologies compared, tools evaluated, benchmarks?
- **Open questions:** What unresolved? What needs investigation?

Capture EVERYTHING significant. If in doubt — capture it. Better to have extra material for the secretary protocol to process than to lose it.

### Step 2: Write draft

Create file: `meta/drafts/YYYY-MM-DD-HHMMSS-topic.md`

Format:

```
### Draft: [topic]
Date: YYYY-MM-DD HH:MM

#### Decisions
- **[What was decided]**: [why]. Rejected: [what and why].

#### Specifications
- **[What was specified]**: [details — fields, formats, contracts]

#### Business rules
- **[Rule]**: [logic, conditions, examples]

#### Vocabulary
- **[Term]**: [definition]

#### Patterns
- **[Pattern]**: [example from real data]

#### Problems
- **[Problem]**: [cause] -> [resolution]

#### Approach changes
- **Before:** [old approach]. **After:** [new]. **Why:** [reason]

#### Open questions
- [question]
```

Skip empty sections. Only include sections that have content.

### Step 3: Confirm

Report: "Draft saved: meta/drafts/[filename]. N decisions, M specs, K rules, etc."
