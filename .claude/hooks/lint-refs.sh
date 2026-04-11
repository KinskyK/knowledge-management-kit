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
# A. Referential integrity [[CODE]]
# ═══════════════════════════════════════════
echo "A. Referential integrity [[CODE]]"

for f in meta/decisions/*/*.md meta/docs/*/*.md; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  case "$bn" in _index.md|_tags.md) continue ;; esac
  refs=$(grep -o '\[\[[A-Z][A-Z_-]*-[0-9]*\]\]' "$f" 2>/dev/null | sed 's/\[\[//;s/\]\]//' | sort -u)
  for ref in $refs; do
    if ! code_exists "$ref"; then
      error "$bn: [[${ref}]] → file not found"
    fi
  done
done

echo ""

# ═══════════════════════════════════════════
# B. Paths in SKILL.md
# ═══════════════════════════════════════════
echo "B. Paths in SKILL.md"

for skill in .claude/skills/*/SKILL.md; do
  [ -f "$skill" ] || continue
  skill_name=$(basename "$(dirname "$skill")")
  grep -o 'meta/[^ ,;)]*\.md\|agents/[^ ,;)]*\.md' "$skill" 2>/dev/null | sort -u | while read -r p; do
    if [ ! -f "$p" ]; then
      error "$skill_name/SKILL.md: path '$p' → file not found"
    fi
  done
done

echo ""

# ═══════════════════════════════════════════
# C. ADR format contract
# ═══════════════════════════════════════════
echo "C. ADR format contract"

for f in meta/decisions/*/*.md; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  case "$bn" in _index.md|_tags.md) continue ;; esac

  # Line 1: # CODE — title (using em dash —)
  line1=$(head -1 "$f")
  if ! echo "$line1" | grep -qE '^# [A-Z][A-Za-z0-9_-]*-[0-9]+ — .+'; then
    error "$bn: line 1 does not match contract '# CODE — title'"
  fi

  # Line 3: starts with #tag
  line3=$(sed -n '3p' "$f")
  if ! echo "$line3" | grep -qE '^#[a-z]'; then
    error "$bn: line 3 does not contain tags"
  fi

  # Has Status field
  if ! grep -q 'Status' "$f" 2>/dev/null; then
    warn "$bn: missing Status field"
  fi
done

echo ""

# ═══════════════════════════════════════════
# D. Out of sync ADR ↔ domain _index
# ═══════════════════════════════════════════
echo "D. Out of sync ADR ↔ domain _index"

for f in meta/decisions/*/*.md; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  case "$bn" in _index.md|_tags.md) continue ;; esac

  code=$(head -1 "$f" | sed 's/^# \([^ ]*\).*/\1/')
  [ -z "$code" ] && continue
  grep -q "Status.*draft" "$f" 2>/dev/null && continue

  domain_dir=$(dirname "$f")
  domain_index="$domain_dir/_index.md"
  [ -f "$domain_index" ] || continue

  # Check entry exists
  if ! grep -q "^### $code " "$domain_index" 2>/dev/null; then
    error "$code: no entry in $(basename "$domain_dir")/_index.md"
  else
    # Check tags match
    file_tags=$(sed -n '3p' "$f")
    index_tags=$(grep -A1 "^### $code " "$domain_index" 2>/dev/null | tail -1)
    if [ "$file_tags" != "$index_tags" ]; then
      warn "$code: tags diverge — file vs _index"
    fi
  fi
done

echo ""

# ═══════════════════════════════════════════
# E. Orphan tags
# ═══════════════════════════════════════════
echo "E. Orphan tags"

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
      warn "Tag $tag defined in _tags.md but not used in any ADR"
    fi
  done

  # Used but undefined
  for tag in $used_tags; do
    if ! echo "$defined_tags" | grep -qx "$tag"; then
      error "Tag $tag used in ADR but not defined in _tags.md"
    fi
  done
fi

echo ""

# ═══════════════════════════════════════════
# F. Stale review triggers
# ═══════════════════════════════════════════
echo "F. Stale review triggers"

HUB="meta/decisions/_index.md"
if [ -f "$HUB" ]; then
  while IFS= read -r line; do
    # Extract CODE from ⚠ lines
    CODE=$(echo "$line" | grep -oE '[A-Z][A-Za-z0-9_-]*-[0-9]+' | head -1)
    if [ -n "$CODE" ]; then
      # Find the ADR file
      ADR_FILE=$(find meta/decisions -name "${CODE}.md" 2>/dev/null | head -1)
      if [ -n "$ADR_FILE" ] && [ -f "$ADR_FILE" ]; then
        # Check last modification (git)
        LAST_MOD=$(git log -1 --format="%ci" -- "$ADR_FILE" 2>/dev/null | cut -d' ' -f1)
        if [ -n "$LAST_MOD" ]; then
          DAYS_AGO=$(( ($(date +%s) - $(date -j -f "%Y-%m-%d" "$LAST_MOD" +%s 2>/dev/null || date -d "$LAST_MOD" +%s 2>/dev/null || echo 0)) / 86400 ))
          if [ "$DAYS_AGO" -gt 30 ]; then
            warn "$CODE: trigger ⚠ in hub, but file not updated for ${DAYS_AGO} days"
          fi
        fi
      fi
    fi
  done < <(grep "⚠" "$HUB" 2>/dev/null)
fi

echo ""

# ═══════════════════════════════════════════
# G. Orphan ADR (no incoming/outgoing links)
# ═══════════════════════════════════════════
# NOTE: O(n^2) — acceptable for <100 ADR files. For larger projects, consider caching refs.
echo "G. Orphan ADR (no links)"

for f in meta/decisions/*/*.md; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  case "$bn" in _index.md|_tags.md) continue ;; esac

  CODE=$(head -1 "$f" | sed 's/^# \([^ ]*\).*/\1/')
  [ -z "$CODE" ] && continue

  # Skip drafts
  grep -q "Status.*draft" "$f" 2>/dev/null && continue

  # Check if this CODE is referenced by any OTHER ADR file
  HAS_INCOMING=false
  for other in meta/decisions/*/*.md; do
    [ "$other" = "$f" ] && continue
    [ -f "$other" ] || continue
    case "$(basename "$other")" in _index.md|_tags.md) continue ;; esac
    if grep -q "\[\[$CODE\]\]" "$other" 2>/dev/null; then
      HAS_INCOMING=true
      break
    fi
  done

  # Check if this file references any other CODE
  HAS_OUTGOING=false
  if grep -q '\[\[[A-Z]' "$f" 2>/dev/null; then
    HAS_OUTGOING=true
  fi

  if [ "$HAS_INCOMING" = false ] && [ "$HAS_OUTGOING" = false ]; then
    warn "$CODE ($f): no incoming or outgoing [[CODE]] links"
  fi
done

echo ""

# ═══════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════
echo "═══════════════════════════════"
echo "Errors: $ERRORS | Warnings: $WARNINGS"
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo "✓ All clean"
fi

exit 0
