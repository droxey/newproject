# AGENTS.md — AI Agent & Copilot Guide

This project was generated from [`droxey/newproject`](https://github.com/droxey/newproject).

## Template Token System

Files in this repository may contain `[[TOKEN_NAME]]` placeholders. These are replaced at generation time by `init.sh` using `sed`. Remaining tokens are manual placeholders.

| Token | Description |
|---|---|
| `[[PROJECT_NAME]]` | Human-readable project name |
| `[[GITHUB_REPO]]` | Repository slug / directory name |
| `[[GITHUB_USER]]` | GitHub username |
| `[[PROJECT_DESC]]` | Short project description — **replace manually** |
| `[[PROJECT_LOGO]]` | URL to project logo — **replace manually** |

## For AI Agents

- Do not treat `[[TOKEN_NAME]]` strings as code. They are template placeholders.
- Replace `[[PROJECT_DESC]]` and `[[PROJECT_LOGO]]` manually before committing.
- The `Makefile` provides common entry points: `make help`, `make dev`, `make build`, `make deploy`.
- See `CONTRIBUTING.md` for coding conventions.
- `.openclaw/skill.json` is a stub for [OpenClaw](https://github.com/droxey/agentadventure) skill registration. Populate the `skills` array with skill definitions as the project grows.

---

## `init.sh` — Agent Compatibility

### Per-agent compatibility table

| Agent | Shell access | Key blockers |
|---|---|---|
| GitHub Copilot Coding Agent | ✅ | Previously blocked by: secret leak via `-t` flag, SSH-only clone, macOS commands (all now fixed in `init.sh`) |
| Claude (computer-use / bash tool) | ✅ | Previously blocked by: secret leak, SSH-only clone, `exit 1` on success (all now fixed in `init.sh`) |
| ChatGPT (code interpreter) | ⚠️ no network | cannot reach GitHub API at all |
| Grok | ⚠️ limited | Previously blocked by: secret leak (fixed in `init.sh`); still limited by no persistent filesystem |
| Gemini | ⚠️ limited | Previously blocked by: secret leak, SSH-only clone (both fixed in `init.sh`) |

### Blockers

| # | Severity | Status | Blocker | Fix |
|---|---|---|---|---|
| 1 | 🔴 | ✅ fixed | **Secret leak** — passing `GITHUB_TOKEN` via `-t` flag exposes it in shell history and process list | Read from env var as fallback; `-t` flag takes precedence when provided |
| 2 | 🔴 | ✅ fixed | **Wrong exit code** — `exit 1` on success causes agents to retry/abort | Replace with `exit 0` |
| 3 | 🟠 | ✅ fixed | **SSH-only clone** — agent sandboxes have no SSH key; clone and push fail silently | Use HTTPS + `x-access-token:$GITHUB_TOKEN` in remote URL |
| 4 | 🟠 | ✅ fixed | **No env var fallbacks** — agents can't safely inline secrets as flags | `-n`/`-u`/`-r`/`-t` each fall back to `NEWPROJECT_NAME`, `GITHUB_ACTOR`, `NEWPROJECT_REPO`, `GITHUB_TOKEN` |
| 5 | 🟠 | ✅ fixed | **macOS-only commands** — `pbcopy`/`open` abort on Linux containers | OS-aware helpers that degrade silently |
| 6 | 🟡 | ✅ fixed | **Deprecated API header** — `baptiste-preview` removed from GitHub API | Use `application/vnd.github+json` + `X-GitHub-Api-Version: 2022-11-28` |
| 7 | 🟡 | ⬜ open | **No dry-run** — every test invocation creates a real repo | Add `--dry-run` / `-d` flag |
| 8 | 🟢 | ⬜ open | **No machine-readable output** — agents benefit from structured output | Add `-j` JSON flag |

### Recommended invocation for agents (after Phase A fixes)

```bash
# Set credentials in environment — never pass GITHUB_TOKEN as a flag
export GITHUB_TOKEN="ghp_…"
export GITHUB_ACTOR="your-username"
export NEWPROJECT_NAME="My Project"
export NEWPROJECT_REPO="my-repo"

bash init.sh          # reads all values from env vars
# or override selectively:
bash init.sh -n "My Project" -u your-username -r my-repo
```

---

## Implementation Roadmap

### Phase A — Fix hard blockers (prerequisite for agent use)

- [x] Remove debug `echo` statements that leak secrets
- [x] Replace `exit 1` with `exit 0` at end of successful run
- [x] Replace `pbcopy`/`open` with cross-platform `_copy_to_clipboard`/`_open_url` helpers
- [x] Update GitHub API `Accept` header to `application/vnd.github+json` + `X-GitHub-Api-Version: 2022-11-28`
- [x] Add `require_var` input validation after `getopts`
- [x] Add env var fallbacks: `-n` → `NEWPROJECT_NAME`, `-u` → `GITHUB_ACTOR`, `-r` → `NEWPROJECT_REPO`, `-t` → `GITHUB_TOKEN`
- [x] Switch clone and push from SSH (`git@github.com:…`) to HTTPS (`https://x-access-token:TOKEN@github.com/…`)

### Phase B — Reliability

- [x] Input validation via `require_var`
- [x] `sed -i` portability (macOS `-i ''` vs Linux `-i`)
- [x] `shellcheck` clean (zero warnings)

### Phase C — Agent DX

- [ ] Add `--dry-run` / `-d` flag that prints planned actions without making API calls or cloning
- [x] `.devcontainer/devcontainer.json` for Codespaces / Copilot agent contexts
- [x] `.github/copilot-instructions.md` stub in generated template
- [x] `Makefile` with `help`, `dev`, `build`, `deploy` targets
- [ ] `-j` JSON output flag for machine-readable results

### Phase D — Workflow dispatch

- [ ] Add `.github/workflows/init.yml` with `workflow_dispatch` inputs so agents with GitHub API access can trigger project creation without any shell access

### Phase E — README + smoke tests

- [x] Update `README.md` to document new flags and env var fallbacks
- [ ] Per-agent smoke tests (GitHub Actions matrix: ubuntu + macOS)
