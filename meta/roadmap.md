# Roadmap

## Легенда
[ ] не начата | [~] начата/заморожена | [v] активна | [x] завершена

## Стек задач

### Глубина 0

[v] Документ-карта архитектуры (docs/architecture-map.md) — живой документ, обновляется с каждой новой конструкцией
[x] Sessions deep dive — научить агента нырять в старые сессионные блоки при недопонимании или споре о контексте решения
[x] Обязательная секция "Отвергнуто" в ADR — каждое решение хранит отвергнутые альтернативы и причины отказа
[x] Поведенческие триггеры deep dive — протокол переключения внимания на глубокий слой при пересмотре, конфликте, вопросе "почему"
### Глубина 1 — GraphRAG-слой (опциональный)

Стек: LightRAG (insert_custom_kg + hybrid query) + FastEmbed (multilingual-e5-large) + OpenRouter (Gemma 3 12B / Qwen3.6 Plus для merge). Исследование: meta/docs/landscape/graphrag-local-stack.md

[ ] MCP-сервер (~100-150 строк Python): insert_kg, search_knowledge, delete_source, get_graph_stats
[ ] Интеграция extraction в секретарский протокол: Claude при коммите извлекает тройки → insert_custom_kg
[ ] Шаблон extraction: стандартизация entity types (decision, concept, problem, domain, mechanism) и relationship types
[ ] Интеграция query: команда /search через MCP → LightRAG hybrid query (only_need_context=True) → Claude синтезирует ответ
[ ] Тестирование: dummy LLM vs OpenRouter, качество multilingual-e5-large на RU+EN, латентность при 500 docs

## Сессионный контекст
→ meta/sessions.md (отдельный файл; при старте подгружается последний блок)
