#!/bin/bash
# install.sh — Download Knowledge Management Kit template into current project
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/KinskyK/knowledge-management-kit/main/install.sh)"

set -euo pipefail

REPO="KinskyK/knowledge-management-kit"
BRANCH="main"
TARGET="_knowledge"

# Check if _knowledge already exists
if [ -d "$TARGET" ]; then
  echo "⚠ Папка _knowledge/ уже существует."
  echo "  Удалите её (rm -rf _knowledge) и запустите снова."
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
      echo "✓ Скачано через git"
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
if [ "${NEED_CURL:-false}" = true ] || ! command -v git &> /dev/null; then
  TEMP_ZIP=$(mktemp)
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.zip" -o "$TEMP_ZIP"
  TEMP_EXTRACT=$(mktemp -d)
  unzip -q "$TEMP_ZIP" -d "$TEMP_EXTRACT"
  EXTRACTED_DIR=$(ls "$TEMP_EXTRACT")
  if [ -d "$TEMP_EXTRACT/$EXTRACTED_DIR/_knowledge" ]; then
    cp -r "$TEMP_EXTRACT/$EXTRACTED_DIR/_knowledge" .
    echo "✓ Скачано через curl"
  else
    echo "✗ Ошибка: _knowledge/ не найдена в архиве"
    rm -rf "$TEMP_ZIP" "$TEMP_EXTRACT"
    exit 1
  fi
  rm -rf "$TEMP_ZIP" "$TEMP_EXTRACT"
fi

# Verify
if [ ! -f "_knowledge/INTEGRATION.md" ]; then
  echo "✗ Ошибка: INTEGRATION.md не найден"
  exit 1
fi

FILE_COUNT=$(find _knowledge -type f | wc -l | tr -d ' ')
echo ""
echo "✓ Knowledge Management Kit скачан ($FILE_COUNT файлов)"
echo ""
echo "Следующий шаг: откройте Claude Code и вставьте этот промпт:"
echo ""
echo '  В корне проекта лежит папка _knowledge/ — это шаблон системы управления знаниями.'
echo '  Прочитай _knowledge/INTEGRATION.md и выполни интеграцию. Веди меня по шагам.'
echo ""
