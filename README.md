# Agy Orchestrator

[English](README.md) | [繁體中文](README.zh-TW.md)

**Agy Orchestrator** is a cost-aware, cross-provider orchestration layer for **Google Antigravity (Agy)**.

Agy acts as the primary orchestrator agent—handling task decomposition, plan coordination, and final code integration—while delegating software-engineering subtasks to **Claude Code** and **OpenAI Codex** worker models via the `agy-exec` bridge.

---

## Why Agy Orchestrator?

1. **Cross-Provider Model Diversity**: Agy subagents normally expose platform tiers (`inherit`, `flash`, `pro`). Agy Orchestrator bridges Agy to arbitrary external model IDs across Anthropic Claude (`Haiku`, `Sonnet`, `Opus`) and OpenAI Codex (`Luna`, `Terra`, `Sol`).
2. **Cost-Aware Escalation**: Avoid running high-cost flagship models for entire tasks. Cheap models handle discovery, file search, and test triage; mid-tier models handle primary implementation; and expert models are only invoked for difficult architecture decisions or when lower tiers encounter blockers.
3. **Workspace Isolation via Git Worktree**: External workers execute inside isolated, detached Git worktrees by default. They cannot overwrite your working tree directly. Agy reviews reported diffs as proposals and integrates only verified changes.
4. **Independent Cross-Family Review**: Code authored by Claude models can be reviewed by OpenAI models (and vice versa) to eliminate model family blind spots.

---

## Architecture

```mermaid
flowchart TD
    User(["User"]) <--> AgyNode["Agy Main Agent<br/>(Google Antigravity)"]

    subgraph Sub_Orchestrator ["Agy Orchestrator"]
        Router["model-router Skill"]
        Exec["agy-exec CLI Bridge"]
        AgyNode --> Router
        Router --> Exec
    end

    subgraph Sub_Providers ["Provider Workers"]
        ClaudeWorkers["Claude Code CLI<br/>(Haiku 4.5 / Sonnet 5 / Opus 5)"]
        CodexWorkers["OpenAI Codex CLI<br/>(Luna / Terra / Sol 5.6)"]
        Exec -->|"claude -p"| ClaudeWorkers
        Exec -->|"codex exec"| CodexWorkers
    end

    subgraph Sub_Isolation ["Isolation Layer"]
        Worktree["Git Worktree<br/>(Detached Temporary Directory)"]
        ClaudeWorkers -.-> Worktree
        CodexWorkers -.-> Worktree
    end

    Worktree -->|"Git Diff / Report"| Exec
    Exec -->|"Worker Report & Diff"| AgyNode
```

---

## Routing Ladder & Model Matrix

| Work Type | First Choice | Alternate | Escalation / Expert |
|---|---|---|---|
| File discovery, grep plan, docs, boilerplate, simple checks | **Luna** (GPT-5.6) | **Haiku** (Claude 4.5) | Terra |
| Quick codebase exploration, tests, triage | **Haiku** (Claude 4.5) | **Luna** (GPT-5.6) | Sonnet |
| Normal implementation, refactoring, standard debugging | **Sonnet** (Claude 5) | **Terra** (GPT-5.6) | Opus / Sol |
| OpenAI-family implementation or cross-review | **Terra** (GPT-5.6) | **Sonnet** (Claude 5) | Sol |
| Difficult architecture, ambiguous requirements, hard bugs | **Opus** (Claude 5) | **Sol** (GPT-5.6) | Dual Cross-Review |
| Deep reasoning, cross-file verification, race conditions | **Sol** (GPT-5.6) | **Opus** (Claude 5) | Dual Cross-Review |

---

## Repository Structure

```text
agy-orchestrator/
├── bin/
│   └── agy-exec                       # Core CLI execution bridge
├── agy/
│   ├── agents/
│   │   ├── agy-orchestrator/
│   │   │   └── agent.md               # Main orchestrator agent definition
│   │   └── agy-worker/
│   │       └── agent.md               # Generic worker subagent (fallback)
│   ├── templates/
│   │   └── worker.md                  # Source for the per-route worker agents
│   │                                  #   install.sh renders it into
│   │                                  #   haiku/ sonnet/ opus/ luna/ terra/ sol/
│   └── skills/
│       └── model-router/
│           └── SKILL.md               # Model routing skill definition
├── config/
│   └── models.env                     # Model ID mapping & budget configuration
├── examples/
│   └── task-prompts.md                # Real-world prompt examples
├── install.sh                         # Automated installer
├── uninstall.sh                       # Uninstaller
├── README.md                          # English documentation
├── README.zh-TW.md                    # Traditional Chinese documentation
└── .gitignore                         # Git ignore patterns
```

---

## Real-Time Subagent Statusline

When `agy-orchestrator` delegates, it dispatches via `invoke_subagent` with TypeName set to
the **route name** — `haiku`, `sonnet`, `opus`, `luna`, `terra`, or `sol`. Each route has its
own worker agent, rendered by `install.sh` from `agy/templates/worker.md`.

This exists because the Agy statusline renders the subagent's **TypeName**, not its `Role`.
A single shared worker would show every delegation as `Agent(agy-worker)`, leaving the user
unable to tell which external model is running. Per-route agents make it read:

```text
● Agent(sonnet)  sonnet 執行中 · 1m11s
● Agent(terra)   terra 執行中 · 2m32s
```

- **Real-Time Display**: the routed model appears directly in the Agy CLI bottom bar.
- **Progress & Metrics**: active model, elapsed running time, and current tool call.
- **Concurrent Tracking**: parallel workers are shown side by side.

TypeName must match the `--model` value in the `agy-exec` command. `agy-worker` remains as a
fallback for routes without a dedicated agent.

Because route names are ordinary words, `install.sh` never overwrites an agent it did not
generate (it looks for an `agy-orchestrator:generated` marker), and `uninstall.sh` removes
only marked ones.

---

## Worker Report Contract

`agy-exec` runs for minutes. The `agy-worker` subagent that dispatches it is a cheap
`flash_lite` runner, so its natural failure mode is impatience: seeing `RUNNING`, doing
the task itself, and relaying its own output as if the routed model had produced it. A
fabricated "review passed" is indistinguishable from a real one until the real report
arrives minutes later and contradicts it.

Every completed run therefore ends with a sentinel as its final line:

```text
===== AGY_WORKER_END exit=0 =====
```

`agy-exec` also exits with the worker's own exit code, so a failed worker fails the
bridge instead of silently reporting success.

A worker report is only valid when it carries:
- `===== AGY_WORKER_END exit=0 =====`;
- the `🚀 [agy-worker] Starting:` banner naming the routed model;
- an `AGY_WORKER_GIT_DIFF` block, for `--mode edit` tasks.

The orchestrator must not integrate, commit, or treat a review as passed without them.

---

## Prerequisites & Installation

### Requirements
- **Google Antigravity (Agy) CLI**
- **Claude Code CLI** (`claude`), authenticated
- **OpenAI Codex CLI** (`codex`), authenticated
- Git recommended for worktree isolation

### Quick Install
```bash
git clone https://github.com/tern/agy-orchestrator.git
cd agy-orchestrator
./install.sh
```

Ensure `~/.local/bin` is in your `PATH` (e.g., in `~/.zshrc`):
```bash
export PATH="$HOME/.local/bin:$PATH"
```

The installer configures:
- `~/.local/bin/agy-exec` (executable bridge)
- `~/.gemini/config/agents/agy-orchestrator/agent.md` (Agy agent)
- `~/.gemini/config/skills/model-router/SKILL.md` (Agy skill)
- `~/.config/agy-orchestrator/models.env` (model aliases & budget limits)

---

## Smoke Tests

Verify CLI bridge execution directly from your terminal:

```bash
# Test Claude Haiku (inspect mode)
agy-exec --model haiku --mode inspect --task "Say which model route you are and do not modify files."

# Test OpenAI Luna (inspect mode)
agy-exec --model luna --mode inspect --task "Inspect this repository at a high level and list its top-level purpose."
```

---

## CLI Reference (`agy-exec`)

```text
agy-exec --model <haiku|sonnet|opus|luna|terra|sol> --task <text> [options]

Options:
  --model <name>               Model alias (haiku|sonnet|opus|luna|terra|sol)
  --task <text>                Task prompt for the worker
  --cwd <path>                 Working directory (default: pwd)
  --role <text>                Worker role label (e.g., research, implementation, review)
  --mode <inspect|edit>        inspect = read-only; edit = write-capable
  --isolation <worktree|shared> Default: worktree for Git repos, shared otherwise
  --output <path>              Save worker text output to a file
  --keep-worktree              Keep temporary worktree for manual inspection
  -h, --help                   Show help message
```

---

## Using in Antigravity (Agy)

1. Restart Antigravity CLI or IDE.
2. Run `/agents` and select **`agy-orchestrator`**.
3. Use a prompt adopting the routing policy:

```text
Use the orchestrator routing policy. Complete the requested change with cost-aware delegation. Use Luna/Haiku for cheap discovery and tests, Sonnet/Terra for primary implementation and debugging, and only escalate to Opus/Sol when lower tiers fail or expert reasoning is clearly necessary. Use independent cross-family review for important changes and verify the final state in the main workspace.
```

See [`examples/task-prompts.md`](examples/task-prompts.md) for more scenario templates.

---

## Model Aliases & Budget Configuration

Edit your configuration anytime in:
```text
~/.config/agy-orchestrator/models.env
```

When providers rename models, simply update the IDs in this file. No changes to scripts or agent definitions are required.

---

## Codex Sandbox Note

The bridge uses `--sandbox workspace-write` inside the isolated temporary worktree for Codex workers. This avoids tool-provisioning regressions observed in some Codex CLI versions when using `read-only` mode, while the ephemeral worktree guarantees full containment against unauthorized repository modifications.

---

## Uninstallation

To remove installed files:
```bash
./uninstall.sh
```
*Note: `~/.config/agy-orchestrator/models.env` is preserved so your custom configurations are not lost.*

---

## References

- [Google Antigravity Documentation](https://www.agy.dev)
- [Claude Code CLI Documentation](https://code.claude.com/docs)
- [OpenAI Codex CLI](https://github.com/openai/codex)
