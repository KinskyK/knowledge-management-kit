# Project Manifest — {{PROJECT_NAME}}

> Карта файловой структуры проекта. Загружается по запросу.

---

## Структура файлов

```
project/
├── CLAUDE.md                        # точка входа, инициализация
├── Full Attention Residuals.md      # спецификация FAR-протокола
├── meta/
│   ├── project_manifest.md          # этот файл (карта структуры)
│   ├── roadmap.md                   # стек задач, статусы
│   ├── sessions.md                  # сессионный контекст (отделён от roadmap)
│   ├── _tags.md                     # общий словарь хештегов
│   ├── decisions/
│   │   ├── _index.md               # hub решений (таблица доменов)
│   │   └── {{domain}}/
│   │       ├── _index.md           # доменный индекс (детальный скелет)
│   │       └── CODE.md             # атомарные ADR файлы
│   └── docs/
│       ├── _index.md               # hub исследований (таблица тем)
│       └── {{topic}}/
│           ├── _index.md           # индекс темы
│           └── *.md                # исследования
├── agents/
│   ├── AGENT_PROTOCOL.md           # hub протокола агентов
│   ├── pipelines.md                # spoke: пайплайны, HRT, loop-back
│   ├── specialists.md              # spoke: детальные протоколы специалистов
│   ├── context-packages.md         # spoke: Zone/Specialist load, маршрутизация
│   └── verification.md             # spoke: верификация, self-assessment, арбитраж
└── .claude/
    ├── hooks/
    │   ├── pre-commit-secretary.sh  # PreToolUse: секретарский протокол (двухуровневый)
    │   ├── session-start-recovery.sh # SessionStart: автовосстановление + загрузка сессии
    │   ├── pre-compact-handoff.sh   # PreCompact: проверка WARM перед компрессией
    │   ├── post-compact-reload.sh   # PostCompact: восстановление контекста
    │   ├── rebuild-index.sh         # ручной: аварийное восстановление (двухуровневое)
    │   └── lint-refs.sh             # ручной: валидация ссылок, контрактов, тегов
    ├── commands/
    │   ├── far.md                   # команда /far (FAR-аудит)
    │   └── context.md               # команда /context (карта контекста)
    ├── scripts/
    │   └── context.py               # движок /context (forward/reverse/tag search)
    └── settings.local.json          # конфигурация хуков
```

<!-- Обновляй этот файл при добавлении новых директорий или значимых файлов -->
