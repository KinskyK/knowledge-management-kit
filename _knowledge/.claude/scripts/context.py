#!/usr/bin/env python3
"""
context.py — парсит decisions index и строит карты контекста.

4 режима:
  python3 context.py FEAT-01          — forward graph (1-hop, 2-hop, thematic)
  python3 context.py 'FEAT-01!'       — reverse graph (кто зависит от FEAT-01)
  python3 context.py '#performance'   — tag search
  python3 context.py FEAT-01 --json   — forward graph в JSON
"""

import re
import json
import sys
import os
from collections import OrderedDict
from difflib import SequenceMatcher

# ── Constants ──────────────────────────────────────────────────────────

EXCLUDED_TAGS = {"#engine", "#architecture"}
MAX_ENTRIES = 12
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, "..", ".."))
HUB_INDEX = os.path.join(PROJECT_ROOT, "meta", "decisions", "_index.md")
DECISIONS_DIR = os.path.join(PROJECT_ROOT, "meta", "decisions")


# ── Data structures ────────────────────────────────────────────────────

class Entry:
    __slots__ = ("code", "name", "symbol", "tags", "links", "warning", "domain", "description")

    def __init__(self):
        self.code = ""
        self.name = ""
        self.symbol = ""  # ■ ◆ ●
        self.tags = set()
        self.links = []   # direct → refs (codes only)
        self.warning = ""
        self.domain = ""
        self.description = ""


# ── Parsing ────────────────────────────────────────────────────────────

def parse_domain_mapping(text: str) -> dict:
    """Parse 'Маппинг: NPC-*→npc/ | ARC-*→arc/ | ...' into {prefix: dir}."""
    mapping = {}
    m = re.search(r'Маппинг:\s*(.+)', text)
    if not m:
        return mapping
    for chunk in m.group(1).split("|"):
        chunk = chunk.strip()
        match = re.match(r'(\S+)-\*\s*→\s*(\S+?)/?', chunk)
        if match:
            mapping[match.group(1)] = match.group(2).rstrip("/")
    return mapping


def extract_links(line: str) -> list:
    """Extract all [[CODE]] references from a line."""
    return re.findall(r'\[\[([A-Z][\w-]+\d+)\]\]', line)


def parse_entries_from_text(text: str) -> list:
    """Parse ### entries from markdown text."""
    entries = []
    # Split by ### headers
    header_pattern = re.compile(
        r'^###\s+([A-Z][\w-]*-\d+)\s+—\s+(.+?)(?:\s+([■◆●])|\s+~~[■◆●]~~\s+DEPRECATED)\s*$',
        re.MULTILINE
    )

    positions = [(m.start(), m) for m in header_pattern.finditer(text)]

    for idx, (pos, match) in enumerate(positions):
        entry = Entry()
        entry.code = match.group(1)
        entry.name = match.group(2).strip()
        entry.symbol = match.group(3) or "◆"  # DEPRECATED entries default to ◆

        # Get the block of text until next header or end
        end_pos = positions[idx + 1][0] if idx + 1 < len(positions) else len(text)
        block = text[pos + len(match.group(0)):end_pos]

        lines = block.strip().split("\n")
        all_links = []
        desc_parts = []
        for line in lines:
            stripped = line.strip()
            if not stripped:
                continue

            # Tags line: starts with #
            if re.match(r'^#\w', stripped):
                tags = set(re.findall(r'#[\w_]+', stripped))
                entry.tags = tags - EXCLUDED_TAGS

            # Warning line
            elif stripped.startswith("⚠"):
                entry.warning = stripped

            # Links line (→ or влияет на)
            elif "[[" in stripped:
                all_links.extend(extract_links(stripped))

            # Description
            else:
                desc_parts.append(stripped)

        entry.links = list(OrderedDict.fromkeys(all_links))  # dedupe, preserve order
        entry.description = " ".join(desc_parts)
        entries.append(entry)

    return entries


def detect_two_level() -> bool:
    """Check if domain _index.md files exist (two-level structure)."""
    for d in os.listdir(DECISIONS_DIR):
        domain_index = os.path.join(DECISIONS_DIR, d, "_index.md")
        if os.path.isdir(os.path.join(DECISIONS_DIR, d)) and os.path.isfile(domain_index):
            return True
    return False


def load_all_entries() -> tuple:
    """Load all entries. Returns (entries_dict, domain_mapping)."""
    with open(HUB_INDEX, "r", encoding="utf-8") as f:
        hub_text = f.read()

    domain_mapping = parse_domain_mapping(hub_text)
    entries_dict = {}

    if detect_two_level():
        # Two-level: hub has domain table, domain _index.md has entries
        for d in os.listdir(DECISIONS_DIR):
            domain_index = os.path.join(DECISIONS_DIR, d, "_index.md")
            if os.path.isdir(os.path.join(DECISIONS_DIR, d)) and os.path.isfile(domain_index):
                with open(domain_index, "r", encoding="utf-8") as f:
                    domain_text = f.read()
                for entry in parse_entries_from_text(domain_text):
                    entry.domain = d
                    entries_dict[entry.code] = entry
        # Also parse hub in case some entries are only there
        for entry in parse_entries_from_text(hub_text):
            if entry.code not in entries_dict:
                entry.domain = code_to_domain(entry.code, domain_mapping)
                entries_dict[entry.code] = entry
    else:
        # Flat: all entries in hub _index.md
        for entry in parse_entries_from_text(hub_text):
            entry.domain = code_to_domain(entry.code, domain_mapping)
            entries_dict[entry.code] = entry

    return entries_dict, domain_mapping


def code_to_domain(code: str, mapping: dict) -> str:
    """Map CODE to domain directory using prefix mapping."""
    # Try longest prefix first
    for prefix, directory in sorted(mapping.items(), key=lambda x: -len(x[0])):
        if code.startswith(prefix + "-"):
            return directory
    # Fallback: lowercase first alpha part
    m = re.match(r'([A-Z]+(?:-[A-Z]+)*)', code)
    if m:
        return m.group(1).lower().replace("-", "")
    return "unknown"


def code_to_filepath(code: str, domain: str) -> str:
    """Build relative path to decision file."""
    return f"meta/decisions/{domain}/{code}.md"


# ── Fuzzy matching ─────────────────────────────────────────────────────

def fuzzy_suggestions(query: str, codes: list, n: int = 5) -> list:
    """Return top N similar codes."""
    prefix = re.match(r'([A-Z][\w-]*)', query)
    prefix_str = prefix.group(1) if prefix else query

    scored = []
    for c in codes:
        ratio = SequenceMatcher(None, prefix_str.upper(), c.upper()).ratio()
        # Boost prefix matches
        if c.upper().startswith(prefix_str.upper()):
            ratio += 0.5
        scored.append((ratio, c))

    scored.sort(key=lambda x: -x[0])
    return [c for _, c in scored[:n]]


# ── Mode 1: Forward graph ─────────────────────────────────────────────

def forward_graph(code: str, entries: dict, mapping: dict) -> dict:
    """Build forward context map for a code."""
    if code not in entries:
        return None

    target = entries[code]
    direct = []    # 1-hop
    transitive = []  # 2-hop
    thematic = []  # shared tags

    # 1-hop: direct links
    direct_codes = set()
    for link_code in target.links:
        if link_code in entries and link_code != code:
            direct.append(entries[link_code])
            direct_codes.add(link_code)

    # 2-hop: links of direct links
    transitive_codes = set()
    for d_entry in direct:
        for link_code in d_entry.links:
            if link_code != code and link_code not in direct_codes and link_code in entries:
                if link_code not in transitive_codes:
                    transitive.append(entries[link_code])
                    transitive_codes.add(link_code)

    # Thematic: entries sharing >=2 tags (excluding already found)
    seen = direct_codes | transitive_codes | {code}
    target_tags = target.tags
    thematic_with_overlap = []
    for c, e in entries.items():
        if c in seen:
            continue
        overlap = target_tags & e.tags
        if len(overlap) >= 2:
            thematic_with_overlap.append((e, overlap))

    # Sort thematic by number of shared tags descending
    thematic_with_overlap.sort(key=lambda x: -len(x[1]))
    thematic = [(e, tags) for e, tags in thematic_with_overlap]

    # Cap at MAX_ENTRIES with priority: direct > transitive > thematic
    total = len(direct) + len(transitive) + len(thematic)
    if total > MAX_ENTRIES:
        remaining = MAX_ENTRIES
        direct = direct[:remaining]
        remaining -= len(direct)
        transitive = transitive[:remaining]
        remaining -= len(transitive)
        thematic = thematic[:remaining]

    return {
        "target": target,
        "direct": direct,
        "transitive": transitive,
        "thematic": thematic,
    }


def format_forward(result: dict, mapping: dict) -> str:
    """Format forward graph as markdown."""
    target = result["target"]
    lines = [f"## Карта контекста: {target.code}\n"]

    if result["direct"]:
        lines.append("### Прямые зависимости (1 hop)")
        for e in result["direct"]:
            lines.append(f"- {e.code} — {e.name} [{e.symbol}]")
        lines.append("")

    if result["transitive"]:
        lines.append("### Транзитивные зависимости (2 hop)")
        for e in result["transitive"]:
            lines.append(f"- {e.code} — {e.name} [{e.symbol}]")
        lines.append("")

    if result["thematic"]:
        # Collect all shared tags for header
        all_shared = set()
        for _, tags in result["thematic"]:
            all_shared |= tags
        tag_str = ", ".join(sorted(all_shared))
        lines.append(f"### Тематические пересечения (общие теги: {tag_str})")
        for e, tags in result["thematic"]:
            specific_tags = ", ".join(sorted(tags))
            lines.append(f"- {e.code} — {e.name} [{e.symbol}] ({specific_tags})")
        lines.append("")

    # Recommended files
    lines.append("### Рекомендуемый контекст для подгрузки")
    all_entries = (
        result["direct"]
        + result["transitive"]
        + [e for e, _ in result["thematic"]]
    )
    for e in all_entries:
        lines.append(code_to_filepath(e.code, e.domain))

    lines.append(f"Всего: {len(all_entries)} файла" if len(all_entries) < 5
                 else f"Всего: {len(all_entries)} файлов")

    return "\n".join(lines)


def forward_to_json(result: dict, mapping: dict) -> dict:
    """Convert forward graph result to JSON-serializable dict."""
    target = result["target"]

    def entry_dict(e, category, shared_tags=None):
        d = {
            "code": e.code,
            "name": e.name,
            "symbol": e.symbol,
            "category": category,
            "file": code_to_filepath(e.code, e.domain),
        }
        if shared_tags:
            d["shared_tags"] = sorted(shared_tags)
        return d

    items = []
    for e in result["direct"]:
        items.append(entry_dict(e, "direct"))
    for e in result["transitive"]:
        items.append(entry_dict(e, "transitive"))
    for e, tags in result["thematic"]:
        items.append(entry_dict(e, "thematic", tags))

    return {
        "target": {
            "code": target.code,
            "name": target.name,
            "symbol": target.symbol,
            "tags": sorted(target.tags),
        },
        "context_map": items,
        "total_files": len(items),
    }


# ── Mode 2: Reverse graph ─────────────────────────────────────────────

def reverse_graph(code: str, entries: dict, mapping: dict) -> str:
    """Find all entries that reference CODE in their → links."""
    if code not in entries:
        return None

    target = entries[code]
    dependents = []
    for c, e in entries.items():
        if c == code:
            continue
        if code in e.links:
            dependents.append(e)

    # Sort by code
    dependents.sort(key=lambda e: e.code)

    lines = [f"## Обратный граф: {code}\n"]

    if not dependents:
        lines.append("Ни одна запись не ссылается на этот код.")
        return "\n".join(lines)

    lines.append(f"### Кто зависит от {code} ({len(dependents)} записей)")
    for e in dependents:
        lines.append(f"- {e.code} — {e.name} [{e.symbol}]")
    lines.append("")

    lines.append("### Рекомендуемый контекст для подгрузки")
    for e in dependents:
        lines.append(code_to_filepath(e.code, e.domain))
    count = len(dependents)
    lines.append(f"Всего: {count} файла" if count < 5 else f"Всего: {count} файлов")

    return "\n".join(lines)


# ── Mode 3: Tag search ────────────────────────────────────────────────

def tag_search(tag: str, entries: dict) -> str:
    """Find all entries with a given tag."""
    # Normalize: ensure leading #
    if not tag.startswith("#"):
        tag = "#" + tag

    results = []
    for c, e in entries.items():
        if tag in e.tags:
            results.append(e)

    results.sort(key=lambda e: e.code)

    if not results:
        # Check what tags exist
        all_tags = set()
        for e in entries.values():
            all_tags |= e.tags
        similar = [t for t in sorted(all_tags) if tag.lstrip("#") in t.lstrip("#")]
        lines = [f"Тег {tag} не найден."]
        if similar:
            lines.append(f"Похожие: {', '.join(similar[:10])}")
        return "\n".join(lines)

    lines = [f"## Записи с тегом {tag} ({len(results)})\n"]
    for e in results:
        lines.append(f"- {e.code} — {e.name} [{e.symbol}]")

    return "\n".join(lines)


# ── Main ───────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print(__doc__.strip())
        sys.exit(1)

    query = sys.argv[1]
    json_mode = "--json" in sys.argv

    entries, mapping = load_all_entries()
    all_codes = sorted(entries.keys())

    # Mode 3: Tag search
    if query.startswith("#"):
        print(tag_search(query, entries))
        return

    # Mode 2: Reverse graph (trailing !)
    if query.endswith("!"):
        code = query.rstrip("!")
        result = reverse_graph(code, entries, mapping)
        if result is None:
            suggestions = fuzzy_suggestions(code, all_codes)
            print(f"Код {code} не найден. Возможно: {', '.join(suggestions)}")
            sys.exit(1)
        print(result)
        return

    # Mode 1 / 4: Forward graph
    code = query
    result = forward_graph(code, entries, mapping)
    if result is None:
        suggestions = fuzzy_suggestions(code, all_codes)
        print(f"Код {code} не найден. Возможно: {', '.join(suggestions)}")
        sys.exit(1)

    if json_mode:
        print(json.dumps(forward_to_json(result, mapping), ensure_ascii=False, indent=2))
    else:
        print(format_forward(result, mapping))


if __name__ == "__main__":
    main()
