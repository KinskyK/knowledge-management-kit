# Project Manifest — claude-memory-kit

> Карта файловой структуры проекта. Загружается по запросу.

---

## Структура файлов

```
claude-memory-kit/
├── CLAUDE.md                        # точка входа, инициализация
├── Full Attention Residuals.md      # спецификация FAR-протокола
├── README.md                        # документация для пользователей
├── _knowledge/                      # шаблон для установки (копируется в целевой проект)
│   ├── INTEGRATION.md               # скрипт интеграции для Claude
│   ├── CLAUDE.md                    # шаблон CLAUDE.md
│   ├── Full Attention Residuals.md  # шаблон FAR
│   ├── agents/
│   │   └── AGENT_PROTOCOL.md        # шаблон протокола агентов
│   ├── meta/
│   │   ├── roadmap.md               # шаблон roadmap
│   │   ├── sessions.md              # шаблон sessions
│   │   ├── _tags.md                 # шаблон тегов
│   │   ├── project_manifest.md      # шаблон манифеста
│   │   ├── decisions/_index.md      # шаблон hub решений
│   │   └── docs/_index.md           # шаблон hub исследований
│   └── .claude/
│       ├── hooks/*.sh               # шаблоны хуков
│       ├── commands/*.md            # шаблоны команд
│       ├── scripts/context.py       # движок /context
│       └── settings.local.json      # шаблон настроек
├── meta/
│   ├── project_manifest.md          # этот файл (карта структуры)
│   ├── roadmap.md                   # стек задач, статусы
│   ├── sessions.md                  # сессионный контекст (отделён от roadmap)
│   ├── _tags.md                     # общий словарь хештегов
│   ├── decisions/
│   │   ├── _index.md               # hub решений (таблица доменов)
│   │   ├── core/_index.md          # доменный индекс: архитектура системы
│   │   └── integration/_index.md   # доменный индекс: процесс установки
│   └── docs/
│       ├── _index.md               # hub исследований (таблица тем)
│       ├── context-management/_index.md  # индекс: управление контекстом
│       └── landscape/_index.md     # индекс: обзор решений
├── agents/
│   └── AGENT_PROTOCOL.md           # hub протокола агентов
└── .claude/
    ├── hooks/
    │   ├── pre-commit-secretary.sh  # PreToolUse: секретарский протокол
    │   ├── session-start-recovery.sh # SessionStart: автовосстановление
    │   ├── pre-compact-handoff.sh   # PreCompact: проверка WARM
    │   ├── post-compact-reload.sh   # PostCompact: восстановление контекста
    │   ├── rebuild-index.sh         # ручной: аварийное восстановление
    │   └── lint-refs.sh             # ручной: валидация ссылок
    ├── commands/
    │   ├── far.md                   # команда /far (FAR-аудит)
    │   └── context.md               # команда /context (карта контекста)
    ├── scripts/
    │   └── context.py               # движок /context (forward/reverse/tag)
    └── settings.local.json          # конфигурация хуков
```

<!-- Обновляй этот файл при добавлении новых директорий или значимых файлов -->
