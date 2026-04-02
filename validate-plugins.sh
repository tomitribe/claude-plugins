#!/bin/bash
# Validate plugin structure against what Claude Code requires
# Run this before pushing to catch structural issues early

PLUGINS_DIR="$(cd "$(dirname "$0")/plugins" && pwd)"
errors=0
warnings=0

red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$1"; }
green() { printf '\033[0;32m%s\033[0m\n' "$1"; }

for plugin_dir in "$PLUGINS_DIR"/*/; do
  plugin=$(basename "$plugin_dir")
  pjson="$plugin_dir/.claude-plugin/plugin.json"

  echo "--- $plugin"

  # Check plugin.json exists
  if [ ! -f "$pjson" ]; then
    yellow "  WARN: no .claude-plugin/plugin.json (may be a non-skill plugin)"
    warnings=$((warnings + 1))
    continue
  fi

  # Check plugin.json has required fields
  for field in name description version; do
    val=$(python3 -c "import json; print(json.load(open('$pjson')).get('$field', ''))" 2>/dev/null)
    if [ -z "$val" ]; then
      red "  ERROR: plugin.json missing '$field'"
      errors=$((errors + 1))
    fi
  done

  # Check each skill
  for skill_md in "$plugin_dir"/skills/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    skill_name=$(basename "$(dirname "$skill_md")")

    # Check frontmatter has name
    fm_name=$(python3 -c "
import re, sys
with open('$skill_md') as f:
    text = f.read()
m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
if not m:
    sys.exit(0)
for line in m.group(1).split('\n'):
    if line.startswith('name:'):
        print(line.split(':', 1)[1].strip())
        break
")
    if [ -z "$fm_name" ]; then
      red "  ERROR: skills/$skill_name/SKILL.md frontmatter missing 'name'"
      errors=$((errors + 1))
    fi

    # Check frontmatter has description
    fm_desc=$(python3 -c "
import re, sys
with open('$skill_md') as f:
    text = f.read()
m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
if not m:
    sys.exit(0)
for line in m.group(1).split('\n'):
    if line.startswith('description:'):
        print('yes')
        break
")
    if [ -z "$fm_desc" ]; then
      red "  ERROR: skills/$skill_name/SKILL.md frontmatter missing 'description'"
      errors=$((errors + 1))
    fi

    # Check frontmatter exists at all
    has_fm=$(head -1 "$skill_md")
    if [ "$has_fm" != "---" ]; then
      red "  ERROR: skills/$skill_name/SKILL.md has no frontmatter"
      errors=$((errors + 1))
    fi
  done

  # Check at least one skill exists
  skill_count=$(find "$plugin_dir/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$skill_count" = "0" ] && [ -f "$pjson" ]; then
    yellow "  WARN: plugin has plugin.json but no skills"
    warnings=$((warnings + 1))
  fi
done

echo ""
echo "==============================="
if [ $errors -gt 0 ]; then
  red "$errors error(s), $warnings warning(s)"
  exit 1
else
  green "All plugins valid. $warnings warning(s)."
  exit 0
fi
