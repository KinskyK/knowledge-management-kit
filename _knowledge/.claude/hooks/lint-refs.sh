#!/bin/bash
# Hook: lint-refs (advisory)
# Validates referential integrity, ADR format contracts, tag consistency.
# Always exit 0 — advisory mode, not a gate.
# Usage: bash .claude/hooks/lint-refs.sh

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || cd "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || exit 0

ERRORS=0
WARNINGS=0

error() { echo "  ✗ $1"; ERRORS=$((ERRORS + 1)); }
warn()  { echo "  ⚠ $1"; WARNINGS=$((WARNINGS + 1)); }

# Build list of valid codes (one per line)
VALID_CODES=""
for f in meta/decisions/*/*.md; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  if [ "$bn" = "_index.md" ] || [ "$bn" = "_tags.md" ]; then continue; fi
  code=$(head -1 "$f" | sed 's/^# \([^ ]*\).*/\1/')
  [ -n "$code" ] && VALID_CODES="$VALID_CODES
$code"
done

code_exists() {
  echo "$VALID_CODES" | grep -qx "$1"
}

# ═══════════════════════════════════════════
# A. Ссылочная целостность [[CODE]]
# ═══════════════════════════════════════════
echo "A. Ссылочная целостность [[CODE]]"

for f in meta/decisions/*/*.md meta/docs/*/*.md; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  case "$bn" in _index.md|_tags.md) continue ;; esac
  refs=$(grep -o '\[\[[A-Z][A-Z_-]*-[0-9]*\]\]' "$f" 2>/dev/null | sed 's/\[\[//;s/\]\]//' | sort -u)
  for ref in $refs; do
    if ! code_exists "$ref"; then
      error "$bn: [[${ref}]] → файл не найден"
    fi
  done
done

echo ""

# ═══════════════════════════════════════════
# B. Пути в SKILL.md
# ═══════════════════════════════════════════
echo "B. Пути в SKILL.md"

for skill in .claude/skills/*/SKILL.md; do
  [ -f "$skill" ] || continue
  skill_name=$(basename "$(dirname "$skill")")
  grep -o 'meta/[^ ,;)]*\.md\|agents/[^ ,;)]*\.md' "$skill" 2>/dev/null | sort -u | while read -r p; do
    if [ ! -f "$p" ]; then
      error "$skill_name/SKILL.md: путь '$p' → файл не найден"
    fi
  done
done

echo ""

# ═══════════════════════════════════════════
# C. Контракт ADR-формата
# ═══════════════════════════════════════════
echo "C. Контракт ADR-формата"

for f in meta/decisions/*/*.md; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  case "$bn" in _index.md|_tags.md) continue ;; esac

  # Line 1: # CODE — название (using em dash —)
  line1=$(head -1 "$f")
  if ! echo "$line1" | grep -qE '^# [A-Z][A-Za-z0-9_-]*-[0-9]+ — .+'; then
    error "$bn: строка 1 не соответствует контракту '# CODE — название'"
  fi

  # Line 3: starts with #tag
  line3=$(sed -n '3p' "$f")
  if ! echo "$line3" | grep -qE '^#[a-z]'; then
    error "$bn: строка 3 не содержит тегов"
  fi

  # Has Статус field
  if ! grep -q 'Статус' "$f" 2>/dev/null; then
    warn "$bn: нет поля Статус"
  fi
done

echo ""

# ═══════════════════════════════════════════
# D. Рассинхрон ADR ↔ доменный _index
# ═══════════════════════════════════════════
echo "D. Рассинхрон ADR ↔ доменный _index"

for f in meta/decisions/*/*.md; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  case "$bn" in _index.md|_tags.md) continue ;; esac

  code=$(head -1 "$f" | sed 's/^# \([^ ]*\).*/\1/')
  [ -z "$code" ] && continue
  grep -q "Статус.*draft" "$f" 2>/dev/null && continue

  domain_dir=$(dirname "$f")
  domain_index="$domain_dir/_index.md"
  [ -f "$domain_index" ] || continue

  # Check entry exists
  if ! grep -q "^### $code " "$domain_index" 2>/dev/null; then
    error "$code: нет записи в $(basename "$domain_dir")/_index.md"
  else
    # Check tags match
    file_tags=$(sed -n '3p' "$f")
    index_tags=$(grep -A1 "^### $code " "$domain_index" 2>/dev/null | tail -1)
    if [ "$file_tags" != "$index_tags" ]; then
      warn "$code: теги расходятся — файл vs _index"
    fi
  fi
done

echo ""

# ═══════════════════════════════════════════
# E. Orphan-теги
# ═══════════════════════════════════════════
echo "E. Orphan-теги"

if [ -f "meta/_tags.md" ]; then
  # Tags defined in _tags.md
  defined_tags=$(grep '^- #' meta/_tags.md | sed 's/^- \(#[a-z_]*\).*/\1/' | sort)

  # Tags used in ADR files (line 3), excluding _index and _tags
  used_tags=""
  for f in meta/decisions/*/*.md; do
    [ -f "$f" ] || continue
    bn=$(basename "$f")
    case "$bn" in _index.md|_tags.md) continue ;; esac
    used_tags="$used_tags $(sed -n '3p' "$f")"
  done
  used_tags=$(echo "$used_tags" | tr ' ' '\n' | grep '^#' | sort -u)

  # Defined but unused
  for tag in $defined_tags; do
    if ! echo "$used_tags" | grep -qx "$tag"; then
      warn "Тег $tag определён в _tags.md, но не используется ни в одном ADR"
    fi
  done

  # Used but undefined
  for tag in $used_tags; do
    if ! echo "$defined_tags" | grep -qx "$tag"; then
      error "Тег $tag используется в ADR, но не определён в _tags.md"
    fi
  done
fi

echo ""

# ═══════════════════════════════════════════
# Итог
# ═══════════════════════════════════════════
echo "═══════════════════════════════"
echo "Ошибок: $ERRORS | Предупреждений: $WARNINGS"
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo "✓ Всё чисто"
fi

exit 0
