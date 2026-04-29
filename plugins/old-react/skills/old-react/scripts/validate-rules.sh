#!/usr/bin/env bash
set -euo pipefail

# validate-rules.sh — verifies a rule file (or all rule files in rules/) has:
#   - YAML frontmatter with required keys: title, slug, category, impact, tags
#   - category in the closed set; impact in the closed set
#   - slug starts with category prefix and matches the filename basename
#   - body has the "## <title>" heading
#   - body has both **Incorrect** and **Correct** markers
#   - body has at least one fenced code block per marker (>= 4 fence lines)
#
# Usage:
#   validate-rules.sh <file.md>           # validate a single file
#   validate-rules.sh --all <rules-dir>   # validate every non-underscore file under rules/

ALLOWED_CATEGORIES="purity immutable model message effect hooks compose"
ALLOWED_IMPACTS="CRITICAL HIGH MEDIUM LOW"

die() { echo "FAIL: $1: $2" >&2; exit 1; }

# Extract a single YAML scalar (e.g. `slug: foo`) from a file's leading frontmatter.
# Prints the value to stdout (empty if the key is absent). Trailing YAML inline
# comments (whitespace then `#` to end of line) are stripped, matching the YAML
# 1.2 rule that `#` introduces a comment only when preceded by whitespace.
# Limitation: does not understand quoted strings — a `#` after whitespace inside
# `"foo # bar"` would still be treated as a comment.
extract_frontmatter_value() {
  local file="$1" key="$2"
  awk -v k="$key" '
    BEGIN { in_fm = 0 }
    NR == 1 && /^---$/ { in_fm = 1; next }
    in_fm && /^---$/ { in_fm = 0; exit }
    in_fm && $1 == k":" {
      sub(/^[^:]+:[[:space:]]*/, "")
      sub(/[[:space:]]+#.*$/, "")
      print; exit
    }
  ' "$file"
}

validate_file() {
  local file="$1"
  local base
  base="$(basename "$file" .md)"

  # 1. Has frontmatter
  head -1 "$file" | grep -q '^---$' || die "$file" "missing frontmatter (no leading ---)"

  # 2. Required keys — extract each once; absent values fail fast.
  local title slug category impact tags
  title="$(extract_frontmatter_value "$file" title)"
  slug="$(extract_frontmatter_value "$file" slug)"
  category="$(extract_frontmatter_value "$file" category)"
  impact="$(extract_frontmatter_value "$file" impact)"
  tags="$(extract_frontmatter_value "$file" tags)"
  for key_value in "title:$title" "slug:$slug" "category:$category" "impact:$impact" "tags:$tags"; do
    [ -n "${key_value#*:}" ] || die "$file" "missing frontmatter key '${key_value%%:*}'"
  done

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

  # 9. At least one fenced code block under each marker section. A global
  #    fence-count check would accept a file whose blocks all live under
  #    **Incorrect**, leaving **Correct** without an example.
  local section_counts inc_fences cor_fences
  section_counts="$(awk '
    BEGIN { state = "pre"; inc = 0; cor = 0; in_fence = 0 }
    /\*\*Incorrect\*\*/ { state = "inc"; next }
    /\*\*Correct\*\*/   { state = "cor"; next }
    /^```/ {
      in_fence = !in_fence
      if (in_fence) {
        if (state == "inc") inc++
        else if (state == "cor") cor++
      }
    }
    END { print inc, cor }
  ' "$file")"
  inc_fences="${section_counts% *}"
  cor_fences="${section_counts#* }"
  [ "$inc_fences" -ge 1 ] || die "$file" "no fenced code block under **Incorrect** section"
  [ "$cor_fences" -ge 1 ] || die "$file" "no fenced code block under **Correct** section"

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
