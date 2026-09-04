#!/usr/bin/env bash
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"

BIN_DIR="${HOME}/.local/bin"
AGY_AGENT_DIR="${HOME}/.gemini/config/agents/agy-orchestrator"
AGY_WORKER_DIR="${HOME}/.gemini/config/agents/agy-worker"
AGY_SKILL_DIR="${HOME}/.gemini/config/skills/model-router"
CFG_DIR="${HOME}/.config/agy-orchestrator"

mkdir -p "$BIN_DIR" "$AGY_AGENT_DIR" "$AGY_WORKER_DIR" "$AGY_SKILL_DIR" "$CFG_DIR"
install -m 0755 "$SRC/bin/agy-exec" "$BIN_DIR/agy-exec"
install -m 0644 "$SRC/agy/agents/agy-orchestrator/agent.md" "$AGY_AGENT_DIR/agent.md"
install -m 0644 "$SRC/agy/agents/agy-worker/agent.md" "$AGY_WORKER_DIR/agent.md"
install -m 0644 "$SRC/agy/skills/model-router/SKILL.md" "$AGY_SKILL_DIR/SKILL.md"
if [[ ! -f "$CFG_DIR/models.env" ]]; then
  install -m 0600 "$SRC/config/models.env" "$CFG_DIR/models.env"
else
  echo "Keeping existing $CFG_DIR/models.env"
fi

cat <<MSG
Installed Agy Orchestrator.

Files:
  $BIN_DIR/agy-exec
  $AGY_AGENT_DIR/agent.md
  $AGY_WORKER_DIR/agent.md
  $AGY_SKILL_DIR/SKILL.md
  $CFG_DIR/models.env

Next:
  1. Ensure ~/.local/bin is in PATH.
  2. Ensure 'claude' and 'codex' CLIs are installed and authenticated.
  3. Run: agy-exec --help
  4. Restart Agy/Antigravity CLI and open /agents.
  5. Select 'agy-orchestrator'.

Model IDs can be changed later in:
  $CFG_DIR/models.env
MSG
