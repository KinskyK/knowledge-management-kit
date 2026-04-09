# Исследование: локальный GraphRAG-стек для Knowledge Management Kit

**Дата:** 2025-04-09
**Статус:** research-complete
**Теги:** #graphrag #embeddings #vector-store #graph-db #mcp

---

## Контекст

Задача: добавить опциональный слой семантического поиска + автоматический граф знаний поверх markdown-файлов knowledge management kit. Всё локальное, данные не уходят на серверы. Извлечение троек делает Claude (не API), embedding-модель локальная. macOS + Linux. Масштаб: 50-500 документов.

---

## 1. Embedding-модели для локального использования

### Top-5 моделей

| Модель | Параметры | Размер | MTEB | Контекст | Языки | Установка |
|--------|-----------|--------|------|----------|-------|-----------|
| **BGE-M3** (BAAI) | 568M | ~1.2 GB | 63.0 | 8192 tok | 100+ (вкл. RU, EN) | `pip install fastembed` или sentence-transformers |
| **multilingual-e5-large** | ~560M | ~1.1 GB | ~61 | 512 tok | 100+ (вкл. RU, EN) | sentence-transformers |
| **nomic-embed-text-v1.5** | ~137M | ~270 MB | 62.4 | 8192 tok | EN-centric | `pip install sentence-transformers` |
| **gte-multilingual-base** (Alibaba) | 305M | ~600 MB | ~61 | 512 tok | 50+ (вкл. RU, EN) | sentence-transformers |
| **all-MiniLM-L6-v2** | 30M | ~90 MB | 56.3 | 512 tok | EN only | sentence-transformers |

### Ключевые выводы

**all-MiniLM-L6-v2 vs крупные модели:**
- MiniLM: 56.3 MTEB, 56% Top-5 accuracy. Быстрая, легкая, но **только английский** и заметно слабее по качеству.
- BGE-M3: 63.0 MTEB, поддержка русского, 8192 контекст, генерирует и dense и sparse embeddings (гибридный поиск из коробки). Разница в качестве **реальная и существенная** (~12% MTEB).

**Рекомендация для RU+EN:** BGE-M3 — лучший баланс качества, мультиязычности и длины контекста. Для максимальной легковесности — gte-multilingual-base (305M параметров, 600 MB).

### ONNX Runtime для ускорения

**Однозначно стоит.** ONNX Runtime дает 1.4-3x ускорение на CPU, а с оптимизациями (operator fusion) — до 5-7x.

Два подхода:
1. **FastEmbed** (от Qdrant) — `pip install fastembed`. Нет PyTorch в зависимостях, чистый ONNX. Легковесный. Поддерживает BGE-M3.
2. **sentence-transformers[onnx]** — `pip install sentence-transformers[onnx]`. ONNX как backend к привычному API.

FastEmbed предпочтительнее: меньше зависимостей, быстрее, не тянет PyTorch (~2 GB).

### GigaEmbeddings (новинка 2025)

Специализированная RU-модель от Сбера. SOTA на ruMTEB (69.1). Основана на GigaChat-3B с pruning 25% слоев. Пока не ясна доступность для локального использования вне экосистемы Сбера.

---

## 2. Vector Stores

### Сравнительная таблица

| Хранилище | Тип | Язык ядра | Установка | Размер зависимостей | Особенности |
|-----------|-----|-----------|-----------|---------------------|-------------|
| **ChromaDB** | Embedded/Client-server | Rust (с 2025) | `pip install chromadb` | ~100 MB | Простейший API, 4x быстрее после Rust-rewrite |
| **LanceDB** | Embedded | Rust | `pip install lancedb` | ~50 MB | Zero-copy, disk-based, нет сервера |
| **Qdrant** | Embedded/Client-server | Rust | `pip install qdrant-client` + binary | ~200 MB | Лучшая фильтрация, payload support |
| **FAISS** | Library | C++ | `pip install faiss-cpu` | ~30 MB | Batch-optimized, слабый incremental |
| **sqlite-vec** | SQLite extension | C | `pip install sqlite-vec` | ~5 MB | Минимальный, наследник sqlite-vss |

### Для масштаба 50-500 документов

**LanceDB** — оптимальный выбор:
- Встроенный (in-process), файловый, нет сервера
- Rust-ядро, быстрый даже на малых объемах
- Нативная поддержка в MCP-серверах (mcp-local-rag использует его)
- Легковесные зависимости
- Хорошо работает с инкрементальными обновлениями

**ChromaDB** — альтернатива если нужен максимально простой API:
- `pip install chromadb` и всё работает
- Rust-core с 2025, multithreading
- Де-факто стандарт для прототипов

**sqlite-vec** — если хочется минимализма и интеграции с SQLite (теги, метаданные в том же файле).

**FAISS** — не рекомендуется для этого сценария (оптимизирован для batch, неудобен для инкрементального индексирования).

---

## 3. Граф-хранилища

### Сравнение

| Хранилище | Тип | Запросы | Persistence | Масштаб | Установка |
|-----------|-----|---------|-------------|---------|-----------|
| **NetworkX + JSON** | In-memory lib | Python API | JSON/pickle dump | До ~10K nodes | `pip install networkx` |
| **Kuzu** | Embedded graph DB | Cypher | Файловый | Миллионы nodes | `pip install kuzu` |
| **txtai[graph]** | Embeddings + graph | Python API | Файловый | Средний | `pip install txtai[graph]` |

### Kuzu — лучший выбор для graph DB

- Embedded (in-process), C++ ядро, Python bindings
- **Vector search и full-text search встроены** (с 2025)
- Cypher для запросов (совместимость с Neo4j)
- Интеграции с LangChain, LlamaIndex, PyTorch Geometric
- 18x быстрее Neo4j на ingestion
- `pip install kuzu` — одна команда

### Vector + Graph в одном?

**Kuzu** — наиболее близок к этому: embedded graph DB с встроенным vector search и full-text search. Можно хранить и граф знаний, и embeddings в одном хранилище.

**txtai** — embeddings database + graph network в одном фреймворке. `pip install txtai[graph]`. Автоматическое извлечение entities и relationships на ingest. Но более тяжеловесный.

**NetworkX + JSON** — для 50-500 документов вполне достаточно. Простота, нет зависимостей. Но нет persistence из коробки и нет query language.

---

## 4. GraphRAG фреймворки

### Microsoft GraphRAG

- **Репо:** github.com/microsoft/graphrag
- **Подход:** LLM извлекает entities/relations -> граф -> community detection (Leiden) -> summaries per community -> query
- **Локальное использование:** поддерживает LiteLLM (100+ моделей), можно использовать Ollama. Но GPT-4 остается наиболее протестированным. Часто проблемы с JSON-ответами от локальных моделей.
- **Тяжеловесность:** много зависимостей, сложная конфигурация.
- **Вердикт:** НЕ подходит для нашего случая. Слишком тяжелый, требует LLM для извлечения (а у нас Claude делает это вручную).

### nano-graphrag

- **Репо:** github.com/gusye1234/nano-graphrag
- **Размер:** ~1100 строк кода (без тестов и промптов)
- **Подход:** тот же что у MS GraphRAG (extract -> graph -> communities -> summaries), но легковесный
- **Локальные модели:** поддерживает sentence-transformers для embeddings, Ollama для LLM
- **Режимы:** Naive, Local, Global query modes
- **Async, типизированный**
- **Вердикт:** хороший кандидат для изучения архитектуры, но всё равно завязан на LLM для extraction.

### fast-graphrag (Circlemind)

- **Репо:** github.com/circlemind-ai/fast-graphrag
- **Подход:** Personalized PageRank вместо community detection. 27x быстрее GraphRAG, 40% точнее.
- **Стоимость:** 6x дешевле MS GraphRAG (сравнение на Wizard of Oz dataset).
- **MIT лицензия**
- **Вердикт:** интересный алгоритмически, но также требует LLM для extraction.

### LightRAG (HKUDS)

- **Репо:** github.com/HKUDS/LightRAG (25K+ stars)
- **EMNLP 2025 paper**
- **Подход:** dual-level retrieval (low-level entities + high-level knowledge), graph + vector
- **Режимы:** naive, local, global, **hybrid** (graph + vector)
- **Reranker поддерживается**
- **Docker для локальных моделей**
- **Вердикт:** наиболее зрелый и активно развиваемый. Hybrid mode — именно то, что нужно.

### LlamaIndex PropertyGraph

- **Подход:** GraphRAGExtractor извлекает тройки (subject-relation-object), строит PropertyGraphIndex
- **Community detection:** Hierarchical Leiden
- **MarkdownElementNodeParser** для markdown файлов
- **Вердикт:** хороший если уже используешь LlamaIndex, но тяжелые зависимости.

### txtai

- **Подход:** embeddings DB + graph + pipelines в одном фреймворке
- **`pip install txtai[graph]`**
- **Автоматическое извлечение entities на ingest**
- **Knowledge graph + vector search из коробки**
- **CPU-friendly, zero-config**
- **Вердикт:** самый "all-in-one" вариант. Но менее гибкий.

### Итог по фреймворкам

Для нашего случая (Claude сам извлекает тройки, нужен только storage + retrieval) полноценный GraphRAG-фреймворк **избыточен**. Лучше взять отдельные компоненты:
- Vector store (LanceDB/ChromaDB)
- Graph store (Kuzu/NetworkX)
- Свой extraction pipeline (Claude -> JSON -> граф)

---

## 5. MCP-серверы для RAG/Knowledge Management

### Готовые решения

| MCP-сервер | Описание | Стек | Установка |
|------------|----------|------|-----------|
| **knowledge-rag** (lyonzin) | Hybrid search + cross-encoder reranking + markdown-aware chunking. 12 MCP tools. | ONNX, BM25+semantic, RRF fusion | `pip install knowledge-rag` |
| **knowledge-mcp** (olafgeibig) | LightRAG-based knowledge base. Vector + graph RAG. | LightRAG, Python 3.12 | uv, github clone |
| **mcp-local-rag** (shinpr) | Semantic + keyword search. LanceDB backend. | Transformers.js, LanceDB, MiniLM-L6 | `npx` |
| **claude-context** (Zilliz) | Code search MCP. BM25 + dense vector. | Milvus-lite | github clone |
| **lightragmcp** (lalitsuryan) | 30+ tools для LightRAG operations | LightRAG | `uvx`/`npx` |
| **local-knowledge-rag-mcp** (patakuti) | Semantic search по локальным документам | Vector embeddings | pip |

### Наиболее релевантные

**knowledge-rag (lyonzin)** — ближе всего к нашим требованиям:
- 100% локальный, ONNX in-process (нет PyTorch)
- Hybrid search: semantic + BM25, fusion через RRF, reranking через cross-encoder
- Markdown-aware chunking (по заголовкам)
- 12 MCP tools
- Один `pip install`

**knowledge-mcp (olafgeibig)** — если нужен граф:
- Основан на LightRAG (vector + graph)
- Извлечение entities через LLM
- Hybrid retrieval modes

### Стратегия

Можно взять **knowledge-rag** как основу и добавить граф-слой. Или взять **knowledge-mcp** и адаптировать под наш формат markdown-файлов и Claude как extractor.

---

## 6. Альтернативные подходы

### Hybrid search (BM25 + semantic) при 50-500 документах

**Стоит ли?** Да, даже при малом корпусе:
- BM25 ловит точные термины (имена ADR, коды решений типа "DSN-001")
- Semantic ловит смысловые совпадения ("как мы решили проблему с контекстом" -> находит FAR-протокол)
- RRF (Reciprocal Rank Fusion) — простой и эффективный способ объединения
- BGE-M3 генерирует и dense и sparse embeddings нативно — hybrid search "бесплатно"

### Reranking при малом масштабе

**Опционально, но полезно:**
- Cross-encoder reranker (например, `cross-encoder/ms-marco-MiniLM-L-6-v2`, ~80 MB) значительно улучшает precision
- При top-k=20 и rerank до top-5 — почти не влияет на латентность
- FastEmbed поддерживает reranking моделей через ONNX

### Чисто keyword-based граф знаний (без embeddings)

**Реалистично для нашего случая:**
- Claude извлекает тройки из markdown -> JSON
- NetworkX хранит граф
- Поиск по графу: Cypher-like traversal или простой BFS/DFS
- Embeddings нужны только для семантического поиска, не для графа
- **Двухслойная архитектура**: граф знаний (без embeddings) + vector index (с embeddings) — работают параллельно

### ColBERT при малом корпусе

Избыточен. Late interaction модели дают преимущество на больших коллекциях (100K+ документов). При 50-500 документах cross-encoder reranker эффективнее и проще.

---

## 7. Новое в 2025

### Ключевые тренды

1. **From RAG to Context**: RAG эволюционирует из "retrieve-stuff-generate" в knowledge runtime — оркестрацию retrieval, verification, reasoning.

2. **Agentic RAG**: агенты планируют multi-hop retrieval, выбирают инструменты, рефлексируют. Наш MCP-подход — именно это.

3. **Graph + Vector convergence**: Kuzu добавил vector search, TigerGraph добавил TigerVector. Тренд на unified storage.

4. **ONNX как стандарт для edge inference**: 65% новых semantic search проектов используют ONNX embeddings.

5. **Static embeddings**: sentence-transformers выпустили static-similarity-mrl-multilingual-v1 — 125x быстрее на CPU чем e5-small. Качество ниже, но для pre-filtering может быть полезно.

6. **LightRAG** (EMNLP 2025) — самый заметный open-source GraphRAG проект года. 25K stars.

### Новые инструменты

- **FastEmbed** — lightweight ONNX embedding от Qdrant
- **LightRAG** — graph + vector RAG framework
- **knowledge-rag MCP** — готовый MCP для Claude Code с hybrid search
- **knowledge-mcp** — LightRAG + MCP
- **GigaEmbeddings** — SOTA для русского языка
- **Kuzu** с vector search — embedded graph DB + vector в одном

---

## Итоговая рекомендация стека

### Минимальный стек (MVP)

```
Embedding:     FastEmbed + BGE-M3 (ONNX, без PyTorch)
Vector store:  LanceDB (embedded, файловый, Rust)
Graph store:   NetworkX + JSON (простота, достаточно для 500 docs)
Search:        Hybrid (BM25 + semantic через BGE-M3 sparse+dense)
MCP:           Свой, на базе knowledge-rag (lyonzin) как референс
Extraction:    Claude сам извлекает тройки -> JSON -> граф
```

**Установка:**
```bash
pip install fastembed lancedb networkx
```
Итого зависимости: ~100 MB (без PyTorch!).

### Продвинутый стек

```
Embedding:     FastEmbed + BGE-M3
Storage:       Kuzu (graph + vector + full-text в одном)
Reranking:     cross-encoder через FastEmbed ONNX
Search:        Hybrid (BM25 + semantic + graph traversal)
MCP:           Свой или адаптированный knowledge-mcp
Extraction:    Claude -> structured JSON -> Kuzu
```

**Установка:**
```bash
pip install fastembed kuzu
```

### Почему не готовый фреймворк?

1. MS GraphRAG, nano-graphrag, fast-graphrag, LightRAG — все завязаны на LLM для extraction. У нас Claude делает это "руками" в рамках секретарского протокола. Лишний слой.
2. Нам нужен **тонкий слой**: index + search + graph storage. Не pipeline с LLM-вызовами.
3. MCP-интеграция проще написать самим, чем адаптировать чужой фреймворк.
4. knowledge-rag (lyonzin) — хороший референс для MCP-части, но без графа. knowledge-mcp (olafgeibig) — референс для graph+vector, но тяжелее.

### Рекомендованная архитектура

```
[markdown files] 
    |
    v
[Claude: extract triples] --> [Graph: NetworkX/Kuzu]
    |                              |
    v                              v
[Chunking: by headers]      [Graph queries: 
    |                         related entities,
    v                         paths, clusters]
[Embedding: BGE-M3/FastEmbed]      |
    |                              |
    v                              v
[Vector: LanceDB]           [Merge results]
    |                              |
    v                              v
[BM25 index]                [Rerank (optional)]
    |                              |
    v                              v
[RRF fusion] -----------------> [MCP server]
                                   |
                                   v
                              [Claude Code]
```

### Фазирование

1. **Фаза 1 (MVP):** FastEmbed + BGE-M3 + LanceDB + hybrid search. Без графа. MCP с search/index tools.
2. **Фаза 2:** Добавить граф (NetworkX + JSON). Claude извлекает тройки при коммите. Graph traversal как дополнительный retrieval.
3. **Фаза 3:** Опционально мигрировать на Kuzu если граф растет или нужны сложные запросы.

---

## Источники

- [Best Embedding Models 2025 MTEB](https://app.ailog.fr/en/blog/guides/choosing-embedding-models)
- [Open-Source Embedding Models Benchmarked](https://supermemory.ai/blog/best-open-source-embedding-models-benchmarked-and-ranked/)
- [BentoML: Open-Source Embedding Models 2026](https://www.bentoml.com/blog/a-guide-to-open-source-embedding-models)
- [Vector Database Comparison 2026](https://4xxi.com/articles/vector-database-comparison/)
- [Chroma vs LanceDB](https://zilliz.com/comparison/chroma-vs-lancedb)
- [Kuzu GitHub](https://github.com/kuzudb/kuzu)
- [Kuzu: Embedded Graph Database](https://thedataquarry.com/blog/embedded-db-2/)
- [Microsoft GraphRAG](https://github.com/microsoft/graphrag)
- [nano-graphrag](https://github.com/gusye1234/nano-graphrag)
- [fast-graphrag (Circlemind)](https://github.com/circlemind-ai/fast-graphrag)
- [LightRAG (HKUDS)](https://github.com/HKUDS/LightRAG)
- [knowledge-rag MCP](https://github.com/lyonzin/knowledge-rag)
- [knowledge-mcp (olafgeibig)](https://github.com/olafgeibig/knowledge-mcp)
- [mcp-local-rag](https://github.com/shinpr/mcp-local-rag)
- [FastEmbed (Qdrant)](https://github.com/qdrant/fastembed)
- [Sentence Transformers ONNX](https://sbert.net/docs/sentence_transformer/usage/efficiency.html)
- [GigaEmbeddings](https://aclanthology.org/2025.bsnlp-1.3/)
- [txtai](https://github.com/neuml/txtai)
- [RAG Review 2025](https://ragflow.io/blog/rag-review-2025-from-rag-to-context)
- [Hybrid Search for RAG](https://blog.premai.io/hybrid-search-for-rag-bm25-splade-and-vector-search-combined/)
- [sqlite-vss -> sqlite-vec](https://github.com/asg017/sqlite-vss)
