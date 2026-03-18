#!/bin/bash
# Update all installed Claude Code plugins
# Reads plugin names from installed_plugins.json — no hardcoded names

INSTALLED="$HOME/.claude/plugins/installed_plugins.json"

if [ ! -f "$INSTALLED" ]; then
  echo "No installed_plugins.json found"
  exit 1
fi

# Extract plugin keys (format: "name@marketplace")
plugins=$(python3 -c "
import json, sys
with open('$INSTALLED') as f:
    data = json.load(f)
for key in data.get('plugins', {}):
    print(key)
")

if [ -z "$plugins" ]; then
  echo "No plugins found"
  exit 0
fi

echo "Updating $(echo "$plugins" | wc -l | tr -d ' ') plugins..."
echo ""

while IFS= read -r plugin; do
  echo "--- $plugin"
  claude plugin update "$plugin" 2>&1
  echo ""
done <<< "$plugins"

echo "Done. Run /reload-plugins in your session to activate."
