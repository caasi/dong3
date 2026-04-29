#!/usr/bin/env bash
set -euo pipefail

# validate-rules.sh — verifies a rule file (or all rule files in rules/) has:
#   1. YAML frontmatter with required keys: title, slug, category, impact, tags
#   2. category in the closed set
#   3. impact in the closed set
#   4. slug starts with category prefix and matches filename basename
#   5. body has "## <title>" heading
#   6. body has both **Incorrect** and **Correct** markers
#   7. body has at least one fenced code block after each marker
#
# Usage:
#   validate-rules.sh <file.md>           # validate a single file
#   validate-rules.sh --all <rules-dir>   # validate every non-underscore file under rules/

ALLOWED_CATEGORIES="purity immutable model message effect hooks compose"
ALLOWED_IMPACTS="CRITICAL HIGH MEDIUM LOW"

die() { echo "FAIL: $1: $2" >&2; exit 1; }

extract_frontmatter_value() {
  local file="$1" key="$2"
  awk -v k="$key" '
    BEGIN { in_fm = 0 }
    NR == 1 && /^---$/ { in_fm = 1; next }
    in_fm && /^---$/ { in_fm = 0; exit }
    in_fm && $1 == k":" { sub(/^[^:]+:[[:space:]]*/, ""); print; exit }
  ' "$file"
}

validate_file() {
  local file="$1"
  local base
  base="$(basename "$file" .md)"

  # 1. Has frontmatter
  head -1 "$file" | grep -q '^---$' || die "$file" "missing frontmatter (no leading ---)"

  # 2. Required keys
  for key in title slug category impact tags; do
    local value
    value="$(extract_frontmatter_value "$file" "$key")"
    [ -n "$value" ] || die "$file" "missing frontmatter key '$key'"
  done

  local title slug category impact
  title="$(extract_frontmatter_value "$file" title)"
  slug="$(extract_frontmatter_value "$file" slug)"
  category="$(extract_frontmatter_value "$file" category)"
  impact="$(extract_frontmatter_value "$file" impact)"

  # 3. category in allowed set
  echo "$ALLOWED_CATEGORIES" | tr ' ' '\n' | grep -qx "$category" \
    || die "$file" "category '$category' not in allowed set: $ALLOWED_CATEGORIES"

  # 4. impact in allowed set
  echo "$ALLOWED_IMPACTS" | tr ' ' '\n' | grep -qx "$impact" \
    || die "$file" "impact '$impact' not in allowed set: $ALLOWED_IMPACTS"

  # 5. slug starts with category prefix
  case "$slug" in
    "$category"-*) ;;
    *) die "$file" "slug '$slug' does not start with category prefix '$category-'" ;;
  esac

  # 6. slug matches filename basename
  [ "$slug" = "$base" ] || die "$file" "slug '$slug' does not match filename basename '$base'"

  # 7. Body has the title heading
  grep -qF "## $title" "$file" || die "$file" "missing '## $title' heading in body"

  # 8. Has Incorrect and Correct markers
  grep -q '\*\*Incorrect\*\*' "$file" || die "$file" "missing **Incorrect** marker"
  grep -q '\*\*Correct\*\*' "$file" || die "$file" "missing **Correct** marker"

  # 9. Has at least two fenced code blocks (one per Incorrect/Correct)
  local fence_count
  fence_count="$(grep -c '^```' "$file" || true)"
  if [ "$fence_count" -lt 4 ]; then
    die "$file" "expected at least 2 fenced code blocks (4 fence lines), got $fence_count fence lines"
  fi

  echo "OK: $file"
}

if [ "${1:-}" = "--all" ]; then
  rules_dir="${2:?--all requires a rules directory argument}"
  found_any=0
  for f in "$rules_dir"/*.md; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
      _*) continue ;;
    esac
    found_any=1
    validate_file "$f"
  done
  [ "$found_any" -eq 1 ] || die "$rules_dir" "no rule files found"
else
  [ -n "${1:-}" ] || { echo "Usage: $0 <file.md> | --all <rules-dir>" >&2; exit 2; }
  validate_file "$1"
fi
