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
### Черновик: [тема]
Дата: YYYY-MM-DD HH:MM

#### Решения
- **[Что решили]**: [почему]. Отвергнуто: [что и почему].

#### Проблемы
- **[Проблема]**: [причина] → [решение]

#### Изменения подхода
- **Было:** [старый подход]. **Стало:** [новый]. **Почему:** [причина]

#### Открытые вопросы
- [вопрос]
```

### Step 3: Confirm

Report: "Черновик записан: meta/drafts/[filename]. N решений, M проблем, K вопросов."
