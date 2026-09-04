#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agy-exec-test.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

printf 'AGY_TASK_BUDGET_USD=0\n' > "$TMP_DIR/models.env"
set +e
AGY_ORCH_STATE_DIR="$TMP_DIR/state" AGY_ORCH_MODELS_FILE="$TMP_DIR/models.env" \
  "$ROOT/bin/agy-exec" --model haiku --mode inspect --task 'budget test' --task-id budget-test \
  > "$TMP_DIR/stdout" 2> "$TMP_DIR/stderr"
STATUS=$?
set -e

[[ "$STATUS" == 3 ]]
grep -Fqx '===== AGY_WORKER_END exit=3 =====' "$TMP_DIR/stdout"
grep -Fq 'reduce scope before retrying' "$TMP_DIR/stderr"
! grep -Fq 'start a new --task-id' "$TMP_DIR/stderr"
RESULT="$(find "$TMP_DIR/state" -name result.json -print -quit)"
python3 - "$RESULT" <<'PY'
import json
import sys

result = json.load(open(sys.argv[1]))
assert result["ok"] is False
assert result["exit"] == 3
assert result["reason"] == "budget_exhausted"
PY

echo 'agy-exec budget exhaustion contract: PASS'
