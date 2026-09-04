#!/usr/bin/env bash
set -euo pipefail
rm -f "$HOME/.local/bin/agy-exec"
rm -rf "$HOME/.gemini/config/agents/agy-orchestrator"
rm -rf "$HOME/.gemini/config/skills/model-router"
echo "Removed executable, Agy agent and skill. Kept ~/.config/agy-orchestrator/models.env so custom model mappings are not lost."
