#!/bin/bash
# install.sh — Download Knowledge Management Kit template into current project
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/KinskyK/knowledge-management-kit/main/install.sh)"

set -euo pipefail

REPO="KinskyK/knowledge-management-kit"
BRANCH="main"
TARGET="_knowledge"
NEED_CURL=false

# Check if _knowledge already exists
if [ -d "$TARGET" ]; then
  echo "⚠ _knowledge/ folder already exists."
  echo "  Delete it (rm -rf _knowledge) and run again."
  exit 1
fi

echo "📦 Downloading Knowledge Management Kit..."

# Method 1: git clone (sparse checkout, fastest)
if command -v git &> /dev/null; then
  TEMP_DIR=$(mktemp -d)
  if git clone --depth 1 --filter=blob:none --sparse \
    "https://github.com/$REPO.git" "$TEMP_DIR" 2>/dev/null; then
    cd "$TEMP_DIR"
    git sparse-checkout set _knowledge 2>/dev/null
    cd - > /dev/null
    if [ -d "$TEMP_DIR/_knowledge" ]; then
      cp -r "$TEMP_DIR/_knowledge" .
      rm -rf "$TEMP_DIR"
      echo "✓ Downloaded via git"
    else
      rm -rf "$TEMP_DIR"
      NEED_CURL=true
    fi
  else
    rm -rf "$TEMP_DIR"
    NEED_CURL=true
  fi
fi

# Method 2: Download zip and extract _knowledge/
if [ "$NEED_CURL" = true ] || ! command -v git &> /dev/null; then
  TEMP_ZIP=$(mktemp)
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.zip" -o "$TEMP_ZIP"
  TEMP_EXTRACT=$(mktemp -d)
  unzip -q "$TEMP_ZIP" -d "$TEMP_EXTRACT"
  EXTRACTED_DIR=$(ls -1 "$TEMP_EXTRACT" | head -1)
  if [ -d "$TEMP_EXTRACT/$EXTRACTED_DIR/_knowledge" ]; then
    cp -r "$TEMP_EXTRACT/$EXTRACTED_DIR/_knowledge" .
    echo "✓ Downloaded via curl"
  else
    echo "✗ Error: _knowledge/ not found in archive"
    rm -rf "$TEMP_ZIP" "$TEMP_EXTRACT"
    exit 1
  fi
  rm -rf "$TEMP_ZIP" "$TEMP_EXTRACT"
fi

# Verify
if [ ! -f "_knowledge/INTEGRATION.md" ]; then
  echo "✗ Error: INTEGRATION.md not found"
  exit 1
fi

FILE_COUNT=$(find _knowledge -type f | wc -l | tr -d ' ')
echo ""
echo "✓ Knowledge Management Kit downloaded ($FILE_COUNT files)"
echo ""
echo "Next step: open Claude Code and paste this prompt:"
echo ""
echo '  There is a _knowledge/ folder in the project root — a knowledge management system template.'
echo '  Read _knowledge/INTEGRATION.md and perform the integration. Guide me through the steps.'
echo ""
