#!/bin/bash
# Hook: pre-commit-secretary
# Fires before git commit (PreToolUse). Reminds Claude to run secretary protocol.

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0
git rev-parse --git-dir > /dev/null 2>&1 || exit 0

# Check what's staged/changed
CHANGED=$(git status --porcelain --no-renames 2>/dev/null | awk '{print $NF}')

HAS_DECISIONS=false
HAS_DOCS=false
HAS_ROADMAP=false
HAS_INDEX=false
HAS_DOCS_INDEX=false
HAS_DOMAIN_INDEX=false
HAS_DOCS_DOMAIN_INDEX=false
HAS_SESSIONS=false

for file in $CHANGED; do
  case "$file" in
    meta/decisions/*/*.md)
      case "$file" in
        */_index.md) HAS_DOMAIN_INDEX=true ;;
        *) HAS_DECISIONS=true ;;
      esac
      ;;
    meta/docs/*/*.md)
      case "$file" in
        */_index.md) HAS_DOCS_DOMAIN_INDEX=true ;;
        *) HAS_DOCS=true ;;
      esac
      ;;
    meta/roadmap.md) HAS_ROADMAP=true ;;
    meta/sessions.md) HAS_SESSIONS=true ;;
    meta/decisions/_index.md) HAS_INDEX=true ;;
    meta/docs/_index.md) HAS_DOCS_INDEX=true ;;
  esac
done

# Build warnings
WARNINGS=""

if [ "$HAS_DECISIONS" = true ]; then
  if [ "$HAS_DOMAIN_INDEX" = false ]; then
    WARNINGS="${WARNINGS}\n⚠ Decisions изменены, но доменный _index.md не обновлён!"
  fi
  if [ "$HAS_INDEX" = false ]; then
    WARNINGS="${WARNINGS}\n⚠ Decisions изменены, но hub _index.md не обновлён!"
  fi
fi

if [ "$HAS_DOCS" = true ]; then
  if [ "$HAS_DOCS_DOMAIN_INDEX" = false ]; then
    WARNINGS="${WARNINGS}\n⚠ Docs изменены, но доменный docs/_index.md не обновлён!"
  fi
  if [ "$HAS_DOCS_INDEX" = false ]; then
    WARNINGS="${WARNINGS}\n⚠ Docs изменены, но hub docs/_index.md не обновлён!"
  fi
fi

if [ "$HAS_SESSIONS" = false ] && [ "$HAS_ROADMAP" = false ]; then
  WARNINGS="${WARNINGS}\n⚠ Ни roadmap.md, ни sessions.md не обновлены!"
fi

# Always show secretary checklist
echo ""
# Check for unprocessed drafts
DRAFTS_DIR="meta/drafts"
DRAFT_COUNT=0
if [ -d "$DRAFTS_DIR" ]; then
  DRAFT_COUNT=$(find "$DRAFTS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$DRAFT_COUNT" -gt 0 ]; then
  echo "📝 ЧЕРНОВИКИ: $DRAFT_COUNT файлов в meta/drafts/"
  echo "  Прочитай и используй как основу для пунктов ниже."
  echo "  После оформления в ADR/sessions — удали обработанные."
  echo ""
fi

echo "📋 СЕКРЕТАРСКИЙ ПРОТОКОЛ:"
echo "  0. Черновики в meta/drafts/ → прочитай, оформи, удали обработанные"
echo "  1. Провёл ли FAR-аудит? (WARM → sessions.md)"
echo "  2. Есть ли незаписанные решения? → decisions/ (не забудь секцию Отвергнуто)"
echo "  3. Есть ли несохранённое исследование? → docs/"
echo "  4. Обновлён ли roadmap.md?"
echo "  5. Старые сессионные блоки — что поглощено?"
echo "  6. Решение с ⚠ → в _index.md?"
echo "  7. Новый файл → обновлён _index.md (доменный + hub)?"

# GraphRAG extraction reminder (only if configured)
if [ -f ".graphrag/config.yaml" ]; then
  echo "  8. GraphRAG: извлечь тройки из изменённых файлов → /graphrag extract --changed"

  # Check if any ADR/docs/sessions changed but GraphRAG might not be updated
  HAS_GRAPHRAG_CANDIDATES=false
  for file in $CHANGED; do
    case "$file" in
      meta/decisions/*/*.md|meta/docs/*/*.md|meta/sessions.md)
        case "$file" in
          */_index.md|*/_tags.md) ;;
          *) HAS_GRAPHRAG_CANDIDATES=true ;;
        esac
        ;;
    esac
  done

  if [ "$HAS_GRAPHRAG_CANDIDATES" = true ]; then
    WARNINGS="${WARNINGS}\n⚠ Файлы для GraphRAG изменены. Запусти /graphrag extract --changed перед коммитом."
  fi
fi

# Validate: orphans against domain _index files
if [ "$HAS_DECISIONS" = true ]; then
  ORPHANS=""
  for f in meta/decisions/*/*.md; do
    [ -f "$f" ] || continue
    case "$f" in
      */_index.md|*/_tags.md) continue ;;
    esac
    CODE=$(head -1 "$f" | sed 's/^# \([^ ]*\).*/\1/')
    if [ -n "$CODE" ]; then
      if grep -q "^- \*\*Статус\*\*:.*draft" "$f" 2>/dev/null; then
        continue
      fi
      DOMAIN_DIR=$(dirname "$f")
      DOMAIN_INDEX="$DOMAIN_DIR/_index.md"
      if [ -f "$DOMAIN_INDEX" ]; then
        if ! grep -q "$CODE" "$DOMAIN_INDEX" 2>/dev/null; then
          ORPHANS="${ORPHANS}\n  - $f ($CODE) — нет в $DOMAIN_INDEX"
        fi
      else
        ORPHANS="${ORPHANS}\n  - $f ($CODE) — доменный _index.md отсутствует!"
      fi
    fi
  done

  # Check that all domains with ADR files have entries in hub
  HUB="meta/decisions/_index.md"
  if [ -f "$HUB" ]; then
    for domain_dir in meta/decisions/*/; do
      [ -d "$domain_dir" ] || continue
      domain=$(basename "$domain_dir")
      adr_count=$(ls "$domain_dir"/*.md 2>/dev/null | grep -cv '_index.md\|_tags.md' 2>/dev/null)
      if [ "$adr_count" -gt 0 ]; then
        if ! grep -qi "$domain" "$HUB" 2>/dev/null; then
          WARNINGS="${WARNINGS}\n⚠ Домен '$domain' не найден в hub _index.md!"
        fi
      fi
    done
  fi

  if [ -n "$ORPHANS" ]; then
    echo ""
    echo "🔍 Orphan файлы (accepted без записи в _index.md):"
    echo -e "$ORPHANS"
  fi
fi

# Validate sessions.md block format (Темы: line)
if [ "$HAS_SESSIONS" = true ] && [ -f "meta/sessions.md" ]; then
  MISSING_TOPICS=""
  while IFS= read -r line_num; do
    LINE1=$(sed -n "$((line_num + 1))p" "meta/sessions.md")
    LINE2=$(sed -n "$((line_num + 2))p" "meta/sessions.md")
    if ! echo "$LINE1" | grep -q "^Темы:" && ! echo "$LINE2" | grep -q "^Темы:"; then
      MISSING_TOPICS="${MISSING_TOPICS}\n  - строка ${line_num}: блок без строки 'Темы:'"
    fi
  done < <(grep -n "^### Сессия" "meta/sessions.md" | cut -d: -f1)
  if [ -n "$MISSING_TOPICS" ]; then
    WARNINGS="${WARNINGS}\n⚠ sessions.md: блоки без ключевых слов (строка 'Темы:' после заголовка):${MISSING_TOPICS}"
  fi
fi

# Validate ADR content: check for Отвергнуто section in changed files
if [ "$HAS_DECISIONS" = true ]; then
  MISSING_REJECTED=""
  for f in $CHANGED; do
    case "$f" in
      meta/decisions/*/*.md)
        bn=$(basename "$f")
        case "$bn" in _index.md|_tags.md) continue ;; esac
        if [ -f "$f" ] && ! grep -q "Отвергнуто" "$f" 2>/dev/null; then
          MISSING_REJECTED="${MISSING_REJECTED}\n  - $f"
        fi
        ;;
    esac
  done
  if [ -n "$MISSING_REJECTED" ]; then
    WARNINGS="${WARNINGS}\n⚠ ADR без секции Отвергнуто (рекомендуется при редактировании):${MISSING_REJECTED}"
  fi
fi

# Warn if committing decisions but no drafts exist
if [ "$DRAFT_COUNT" -eq 0 ] && [ "$HAS_DECISIONS" = true ]; then
  WARNINGS="${WARNINGS}\n⚠ Коммитишь решения без черновиков обсуждений. Запиши: /draft"
fi

if [ -n "$WARNINGS" ]; then
  echo ""
  echo -e "$WARNINGS"
fi

echo ""
exit 0
