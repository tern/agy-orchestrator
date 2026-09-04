#!/usr/bin/env bash
set -euo pipefail
rm -f "$HOME/.local/bin/agy-exec" "$HOME/.local/bin/agy-audit"
rm -rf "$HOME/.gemini/config/agents/agy-orchestrator"
rm -rf "$HOME/.gemini/config/agents/agy-worker"
# Route worker agents use ordinary words as names, so remove only what this project
# generated — never an agent the user happens to have under the same name.
for route in haiku sonnet opus luna terra sol; do
  dest="$HOME/.gemini/config/agents/${route}/agent.md"
  if [[ -f "$dest" ]] && grep -q "agy-orchestrator:generated" "$dest"; then
    rm -rf "$HOME/.gemini/config/agents/${route}"
  fi
done
rm -rf "$HOME/.gemini/config/skills/model-router"
echo "Removed executable, Agy agents and skill."
echo "Kept ~/.config/agy-orchestrator/models.env (custom model mappings)."
echo "Kept ~/.local/share/agy-orchestrator/runs (result.json records and the cost ledger)."
