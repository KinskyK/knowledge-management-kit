#!/bin/bash
# Hook: rebuild-index (EMERGENCY)
# Manual run: bash .claude/hooks/rebuild-index.sh
# Generates two-level structure:
#   1. Domain _index.md from ADR files (decisions) / doc files (docs)
#   2. Hub _index.md from domain indexes
#
# ADR contract: line 1 = "# CODE — title", line 3 = "#tags", last ^- **Status**:^ = status
# Docs contract: line 1 = "# title", tags = first line starting with #tag
#
# Entry summaries are NOT restored — a placeholder is used.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$PROJECT_DIR"

DECISIONS_DIR="meta/decisions"
DOCS_DIR="meta/docs"

# Status symbol mapping
status_symbol() {
  local status="$1"
  # Direct symbol check first
  if echo "$status" | grep -q "■"; then echo "■"
  elif echo "$status" | grep -q "◆"; then echo "◆"
  elif echo "$status" | grep -q "●"; then echo "●"
  # Fallback to text match
  elif echo "$status" | grep -qi "аксиома\|axiom"; then echo "■"
  elif echo "$status" | grep -qi "правило\|rule"; then echo "◆"
  elif echo "$status" | grep -qi "гипотеза\|hypothesis"; then echo "●"
  else echo "?"
  fi
}

# ═══════════════════════════════════════════════
# DECISIONS
# ═══════════════════════════════════════════════

echo "=== Decisions ==="

# Domain display names — customize per project
domain_name() {
  echo "$1"
}

# Collect hub data
declare -a HUB_DOMAINS=()
declare -a HUB_COUNTS=()
declare -a HUB_AXIOMS=()
declare -a HUB_RULES=()
declare -a HUB_HYPOTHESES=()
declare -a HUB_TRIGGERS=()

for domain_dir in "$DECISIONS_DIR"/*/; do
  [ -d "$domain_dir" ] || continue
  domain=$(basename "$domain_dir")

  # Collect entries for this domain
  COUNT=0
  AXIOM=0
  RULE=0
  HYPOTHESIS=0
  ENTRIES=""
  TRIGGERS=""

  for f in "$domain_dir"/*.md; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
      _index.md|_tags.md) continue ;;
    esac

    # Parse ADR contract
    TITLE_LINE=$(head -1 "$f")
    TITLE="${TITLE_LINE#\# }"
    TAGS=$(sed -n '3p' "$f")
    STATUS=$(grep "^- \*\*Status\*\*:" "$f" 2>/dev/null | tail -1 | sed 's/^- \*\*Status\*\*: //')

    # Skip drafts
    if echo "$STATUS" | grep -q "draft"; then
      continue
    fi

    SYMBOL=$(status_symbol "$STATUS")
    COUNT=$((COUNT + 1))
    case "$SYMBOL" in
      "■") AXIOM=$((AXIOM + 1)) ;;
      "◆") RULE=$((RULE + 1)) ;;
      "●") HYPOTHESIS=$((HYPOTHESIS + 1)) ;;
    esac

    # Extract links (→ lines) and triggers (⚠ lines)
    LINKS=$(grep "^→ " "$f" 2>/dev/null | head -1 || true)
    FILE_TRIGGERS=$(grep "^⚠ " "$f" 2>/dev/null || true)

    ENTRIES="${ENTRIES}### ${TITLE} ${SYMBOL}\n${TAGS}\n[SUMMARY NOT RESTORED]\n"
    if [ -n "$LINKS" ]; then
      ENTRIES="${ENTRIES}${LINKS}\n"
    fi
    if [ -n "$FILE_TRIGGERS" ]; then
      ENTRIES="${ENTRIES}${FILE_TRIGGERS}\n"
      TRIGGERS="${TRIGGERS}${FILE_TRIGGERS}\n"
    fi
    ENTRIES="${ENTRIES}\n"
  done

  if [ "$COUNT" -eq 0 ]; then
    continue
  fi

  # Write domain _index.md
  DOMAIN_DISPLAY=$(domain_name "$domain")
  DOMAIN_INDEX="$domain_dir/_index.md"

  {
    echo "# ${DOMAIN_DISPLAY}"
    echo "Decisions: ${COUNT} | ■ ${AXIOM} | ◆ ${RULE} | ● ${HYPOTHESIS}"
    echo ""
    echo -e "$ENTRIES"
    if [ -n "$TRIGGERS" ]; then
      echo "## ⚠ Review triggers"
      echo -e "$TRIGGERS"
    fi
    echo "---"
    echo "Restored: $(date '+%Y-%m-%d %H:%M')"
    echo "WARNING: all [SUMMARY NOT RESTORED] lines require manual filling."
  } > "$DOMAIN_INDEX"

  echo "  ✓ $DOMAIN_INDEX ($COUNT entries)"

  # Collect for hub
  HUB_DOMAINS+=("$domain")
  HUB_COUNTS+=("$COUNT")
  HUB_AXIOMS+=("$AXIOM")
  HUB_RULES+=("$RULE")
  HUB_HYPOTHESES+=("$HYPOTHESIS")
  HUB_TRIGGERS+=("$TRIGGERS")
done

# Write decisions hub
TOTAL=0
TOTAL_A=0
TOTAL_R=0
TOTAL_H=0
for i in "${!HUB_COUNTS[@]}"; do
  TOTAL=$((TOTAL + HUB_COUNTS[i]))
  TOTAL_A=$((TOTAL_A + HUB_AXIOMS[i]))
  TOTAL_R=$((TOTAL_R + HUB_RULES[i]))
  TOTAL_H=$((TOTAL_H + HUB_HYPOTHESES[i]))
done

{
  echo "# Decisions Hub"
  echo "Decisions: ${TOTAL} | ■ ${TOTAL_A} | ◆ ${TOTAL_R} | ● ${TOTAL_H}"
  echo "Domain indexes: ${DECISIONS_DIR}/{domain}/_index.md"
  echo ""
  echo "Legend: ■ AXIOM | ◆ RULE | ● HYPOTHESIS"
  echo ""
  echo "## Domains"
  echo "| Domain | Decisions | Stats | Description |"
  echo "|--------|-----------|-------|-------------|"

  for i in "${!HUB_DOMAINS[@]}"; do
    d="${HUB_DOMAINS[i]}"
    DISPLAY=$(domain_name "$d")
    STATS="■ ${HUB_AXIOMS[i]} ◆ ${HUB_RULES[i]} ● ${HUB_HYPOTHESES[i]}"
    echo "| ${d} | ${HUB_COUNTS[i]} | ${STATS} | ${DISPLAY} |"
  done

  echo ""

  # Aggregate all triggers
  ALL_TRIGGERS=""
  for i in "${!HUB_TRIGGERS[@]}"; do
    if [ -n "${HUB_TRIGGERS[i]}" ]; then
      ALL_TRIGGERS="${ALL_TRIGGERS}${HUB_TRIGGERS[i]}"
    fi
  done

  if [ -n "$ALL_TRIGGERS" ]; then
    echo "## ⚠ Review triggers"
    echo -e "$ALL_TRIGGERS"
  fi

  echo "---"
  echo "Restored: $(date '+%Y-%m-%d %H:%M')"
} > "$DECISIONS_DIR/_index.md"

echo "  ✓ $DECISIONS_DIR/_index.md (hub, $TOTAL entries)"

# ═══════════════════════════════════════════════
# DOCS
# ═══════════════════════════════════════════════

echo ""
echo "=== Docs ==="

declare -a DOCS_HUB_TOPICS=()
declare -a DOCS_HUB_COUNTS=()

for topic_dir in "$DOCS_DIR"/*/; do
  [ -d "$topic_dir" ] || continue
  topic=$(basename "$topic_dir")

  DOC_COUNT=0
  DOC_ENTRIES=""

  for f in "$topic_dir"/*.md; do
    [ -f "$f" ] || continue
    [ "$(basename "$f")" = "_index.md" ] && continue

    FNAME=$(basename "$f")
    DOC_TITLE=$(head -1 "$f" | sed 's/^# //')
    # Find tags line: first line matching ^#[a-z]
    DOC_TAGS=$(grep -m1 "^#[a-z]" "$f" 2>/dev/null || echo "")
    # Find links
    DOC_LINKS=$(grep "^→ " "$f" 2>/dev/null | head -1 || echo "")
    # Find date
    DOC_DATE=$(grep -m1 "^Date:" "$f" 2>/dev/null | sed 's/^Date: //' || echo "")
    if [ -z "$DOC_DATE" ]; then
      DOC_DATE=$(grep -m1 "^Created:" "$f" 2>/dev/null | sed 's/^Created: //' || echo "")
    fi

    DOC_COUNT=$((DOC_COUNT + 1))

    DOC_ENTRIES="${DOC_ENTRIES}### ${FNAME} — ${DOC_TITLE}\n"
    if [ -n "$DOC_TAGS" ]; then
      DOC_ENTRIES="${DOC_ENTRIES}${DOC_TAGS}\n"
    fi
    DOC_ENTRIES="${DOC_ENTRIES}[SUMMARY NOT RESTORED]\n"
    if [ -n "$DOC_LINKS" ]; then
      DOC_ENTRIES="${DOC_ENTRIES}${DOC_LINKS}\n"
    fi
    if [ -n "$DOC_DATE" ]; then
      DOC_ENTRIES="${DOC_ENTRIES}Created: ${DOC_DATE}\n"
    fi
    DOC_ENTRIES="${DOC_ENTRIES}\n"
  done

  if [ "$DOC_COUNT" -eq 0 ]; then
    continue
  fi

  # Write topic _index.md
  TOPIC_INDEX="$topic_dir/_index.md"
  {
    echo "# Documentation: ${topic}"
    echo "Documents: ${DOC_COUNT}"
    echo ""
    echo -e "$DOC_ENTRIES"
    echo "---"
    echo "Restored: $(date '+%Y-%m-%d %H:%M')"
    echo "WARNING: all [SUMMARY NOT RESTORED] lines require manual filling."
  } > "$TOPIC_INDEX"

  echo "  ✓ $TOPIC_INDEX ($DOC_COUNT documents)"

  DOCS_HUB_TOPICS+=("$topic")
  DOCS_HUB_COUNTS+=("$DOC_COUNT")
done

# Handle top-level docs (not in subdirectories)
TOP_LEVEL_DOCS=0
for f in "$DOCS_DIR"/*.md; do
  [ -f "$f" ] || continue
  [ "$(basename "$f")" = "_index.md" ] && continue
  TOP_LEVEL_DOCS=$((TOP_LEVEL_DOCS + 1))
done

# Write docs hub
DOC_TOTAL=0
for c in "${DOCS_HUB_COUNTS[@]}"; do
  DOC_TOTAL=$((DOC_TOTAL + c))
done
DOC_TOTAL=$((DOC_TOTAL + TOP_LEVEL_DOCS))

{
  echo "# Research Map"
  echo "Documents: ${DOC_TOTAL}"
  echo ""
  echo "Rule: before answering a question on a topic — read the file. Do not answer from memory."
  echo "Topic not covered by a file → conduct research, create file, add here."
  echo ""
  echo "## Topics"
  echo "| Topic | Documents |"
  echo "|-------|-----------|"

  for i in "${!DOCS_HUB_TOPICS[@]}"; do
    echo "| ${DOCS_HUB_TOPICS[i]} | ${DOCS_HUB_COUNTS[i]} |"
  done

  if [ "$TOP_LEVEL_DOCS" -gt 0 ]; then
    echo "| (root) | ${TOP_LEVEL_DOCS} |"
  fi

  echo ""
  echo "---"
  echo "Restored: $(date '+%Y-%m-%d %H:%M')"
} > "$DOCS_DIR/_index.md"

echo "  ✓ $DOCS_DIR/_index.md (hub, $DOC_TOTAL documents)"

echo ""
echo "Done. All [SUMMARY NOT RESTORED] lines require manual filling."
