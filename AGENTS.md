# AGENTS.md — AI Agent Support for `newproject`

> Can Copilot, Claude, Grok, ChatGPT, Gemini (and similar coding agents) use `init.sh`
> to scaffold a new GitHub repository on your behalf? This document answers that question,
> explains the current blockers, and provides a prioritized TODO list for making it work.

---

## Table of Contents

1. [Current State: Can Agents Use This Today?](#1-current-state-can-agents-use-this-today)
2. [Blocker Analysis](#2-blocker-analysis)
3. [Proposed Changes](#3-proposed-changes)
4. [TODO List](#4-todo-list)

---

## 1. Current State: Can Agents Use This Today?

**Short answer: Not reliably, and not safely.**

Most coding agents (GitHub Copilot Coding Agent, Claude, Grok, ChatGPT with code execution,
Gemini Advanced) can execute shell commands inside a sandboxed environment. On paper, they
could call `init.sh` directly. In practice, the following blockers make that unsafe or
impractical today:

| Agent | Can Run Shell? | Blocker(s) |
|---|---|---|
| **GitHub Copilot Coding Agent** | ✅ Yes (devcontainer) | Secret leak (#1), SSH clone (#5), macOS commands (#3) |
| **Claude (claude.ai / API)** | ✅ Yes (computer-use / bash tool) | Secret leak (#1), SSH clone (#5), exit code (#2) |
| **ChatGPT (code interpreter)** | ⚠️ Sandboxed, no network | No network access to GitHub API — cannot create repos |
| **Grok (xAI)** | ⚠️ Limited shell | Secret leak (#1), no persistent filesystem |
| **Gemini (Google AI Studio)** | ⚠️ Limited shell | Secret leak (#1), SSH clone (#5) |

---

## 2. Blocker Analysis

### #1 — Token passed as CLI flag leaks the secret (🔴 Critical)

```bash
# init.sh line 13 — flag value
t) GITHUB_TOKEN="$OPTARG"

# init.sh lines 42–53 — debug echo exposes it to stdout
echo $GITHUB_TOKEN
```

Agents capture stdout to parse results. Any debug `echo` of `$GITHUB_TOKEN` would expose
the secret in the agent's context window and execution logs. Additionally, passing a secret
via `-t` makes it visible in the process table (`ps aux`).

**Fix:** Remove all debug echo statements. Support `GITHUB_TOKEN` from the environment so
no secret ever appears on the command line.

---

### #2 — `exit 1` at the end of a successful run (🔴 Critical)

```bash
# init.sh line 116
exit 1   # ❌ non-zero exit code signals failure to every caller
```

Agents check exit codes to determine success or failure. An `exit 1` at the end of a
successful run causes every agent to believe the script failed, triggering retries or
error-handling paths.

**Fix:** Replace `exit 1` with `exit 0`.

---

### #3 — macOS-only commands make the script non-portable (🟠 High)

```bash
# init.sh lines 74–75
echo $REPO_PATH | pbcopy   # macOS only
open $REPO_URL/settings    # macOS only
```

All coding agents execute in Linux containers (devcontainers, Docker, cloud VMs). Neither
`pbcopy` nor `open` exists on Linux. On a 422 response the script hits these commands and
terminates immediately with a "command not found" error rather than displaying the helpful
error message.

**Fix:** Wrap clipboard and browser-open calls in OS-detection helpers that degrade
gracefully when the commands are unavailable.

---

### #4 — No environment variable fallback for required inputs (🟠 High)

Agents work with environment variables naturally (via `.env`, `devcontainer.json` secrets,
Actions secrets, etc.). Requiring every value to be passed as a CLI flag means the agent
must construct the full command string with all secrets inline.

**Fix:** For each flag, fall back to a corresponding environment variable:

| Flag | Env Var fallback |
|---|---|
| `-n` | `NEWPROJECT_NAME` |
| `-u` | `GITHUB_USER` or `GITHUB_ACTOR` |
| `-r` | `NEWPROJECT_REPO` |
| `-t` | `GITHUB_TOKEN` *(already standard in Actions/Codespaces)* |

---

### #5 — Clone uses SSH (`git@github.com:`), not HTTPS (🟠 High)

```bash
# init.sh line 39
REPO_REMOTE="git@github.com:$REPO_PATH"
```

SSH key auth is rarely available inside agent sandboxes. GitHub Copilot Coding Agent and
most CI-style environments provide a `GITHUB_TOKEN` for HTTPS-authenticated git operations,
not an SSH key.

**Fix:** Use the HTTPS remote with token-authenticated push:
`https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_PATH}.git`

---

### #6 — Deprecated GitHub API header (🟡 Medium)

```bash
# init.sh line 58
-H "Accept: application/vnd.github.baptiste-preview+json"
```

The `baptiste-preview` header was retired. While GitHub currently still accepts it, it may
stop working without warning.

**Fix:** Use the current stable header:
```
-H "Accept: application/vnd.github+json"
-H "X-GitHub-Api-Version: 2022-11-28"
```

---

### #7 — No dry-run mode (🟡 Medium)

Agents often test a command before committing to a side-effecting action. Without a dry-run
flag, every test invocation actually creates a repository.

**Fix:** Add a `-d` dry-run flag that prints the API request and resolved token values
(excluding secrets) without executing any `curl`, `git clone`, or `git push` calls.

---

### #8 — No machine-readable output option (🟢 Low)

Agents that parse script output benefit from structured output (JSON) rather than
human-readable `[NEW]`/`[ERR]` lines. This is a nice-to-have, not a blocker.

**Fix:** Add a `-j` flag that emits a JSON summary on stdout:
```json
{ "status": "ok", "repo_url": "https://github.com/user/repo" }
```

---

## 3. Proposed Changes

### `init.sh` changes

```bash
# 1. Read all inputs from env vars if not provided via flags
#    (flag value wins; env var is the fallback when the flag was omitted)
PROJECT_NAME="${PROJECT_NAME:-$NEWPROJECT_NAME}"
GITHUB_USER="${GITHUB_USER:-$GITHUB_ACTOR}"
# GITHUB_TOKEN is already conventional in Actions/Codespaces — no rename needed

# 2. Remove all debug echo statements (lines 42–53)

# 3. Use HTTPS remote with token auth
REPO_REMOTE="https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_PATH}.git"

# 4. Update API header
-H "Accept: application/vnd.github+json" \
-H "X-GitHub-Api-Version: 2022-11-28" \

# 5. Replace pbcopy/open with OS-aware helpers
function _copy_to_clipboard() {
    if command -v pbcopy &>/dev/null; then
        echo "$1" | pbcopy
    elif command -v xclip &>/dev/null; then
        echo "$1" | xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
        echo "$1" | xsel --clipboard --input
    fi
    # silently skip if no clipboard tool is available (agent environments)
}

# 6. Fix exit code
exit 0   # was: exit 1
```

### New file: `.devcontainer/devcontainer.json`

Provide a ready-made Codespaces / Copilot Coding Agent environment with `GITHUB_TOKEN`
automatically forwarded and `bash`, `curl`, `git` all pre-installed:

```json
{
  "name": "newproject",
  "image": "mcr.microsoft.com/devcontainers/universal:2"
}
```

In GitHub Codespaces, `GITHUB_TOKEN` is automatically injected at runtime — no explicit
forwarding is needed. For local devcontainers, set `GITHUB_TOKEN` in your shell before
opening VS Code and it will be inherited automatically.

### New file: `.github/copilot-instructions.md` stub (in the template)

A stub that every generated project inherits, explaining the project context to any AI
agent that opens the repo:

```markdown
# Copilot Instructions — [[PROJECT_NAME]]

[[PROJECT_DESC]]

## Key entry points
- ...

## Conventions
- ...
```

---

## 4. TODO List

Items are ordered by priority. Complete Phase A before Phase B, etc.

---

### Phase A — Fix Blockers (agents cannot work until these are done)

- [ ] **A.1** Remove debug `echo` statements in `init.sh` (lines 42–53) that leak `$GITHUB_TOKEN` to stdout
- [ ] **A.2** Replace `exit 1` at the end of `init.sh` with `exit 0`
- [ ] **A.3** Add environment variable fallbacks for every required flag:
  - `-n` → `NEWPROJECT_NAME`
  - `-u` → `GITHUB_USER` (already set in Actions/Codespaces as `GITHUB_ACTOR`)
  - `-r` → `NEWPROJECT_REPO`
  - `-t` → `GITHUB_TOKEN` (already the standard Actions/Codespaces secret)
- [ ] **A.4** Switch `REPO_REMOTE` from SSH (`git@github.com:`) to HTTPS with token auth (`https://x-access-token:${GITHUB_TOKEN}@github.com/...`)
- [ ] **A.5** Replace `pbcopy` / `open` calls with OS-aware `_copy_to_clipboard` and `_open_url` helpers that silently skip on Linux/agent environments

---

### Phase B — Improve Reliability (agents work but may fail on edge cases)

- [ ] **B.1** Update the GitHub API `Accept` header from `baptiste-preview` to `application/vnd.github+json` and add `X-GitHub-Api-Version: 2022-11-28`
- [ ] **B.2** Add `require_var` input validation — fail fast with a clear `[ERR]` message when a required value is missing rather than producing a corrupt repo
- [ ] **B.3** Fix `sed -i` portability: detect macOS (`uname -s` = `Darwin`) and pass `sed -i ''`; use `sed -i` on Linux
- [ ] **B.4** Double-quote all variable expansions in `parse`, `clone`, and `commit` functions to prevent word-splitting issues
- [ ] **B.5** Run `shellcheck init.sh` and resolve all warnings

---

### Phase C — Agent-Friendly Developer Experience

- [ ] **C.1** Add a `-d` dry-run flag to `init.sh` that prints the resolved configuration (without secrets) and skips all API/git calls
- [ ] **C.2** Create `.devcontainer/devcontainer.json` using `mcr.microsoft.com/devcontainers/universal:2` so Copilot Coding Agent, Codespaces, and Claude computer-use can run the script without manual setup
- [ ] **C.3** Add `.github/copilot-instructions.md` stub to the template with `[[PROJECT_NAME]]` and `[[PROJECT_DESC]]` tokens so every generated repo immediately has Copilot context
- [ ] **C.4** Create `Makefile` with a `new` target as a convenience wrapper around `init.sh`:
  ```makefile
  new:
      bash init.sh -n "$(NAME)" -u "$(USER)" -r "$(REPO)"
  ```
- [ ] **C.5** Add a `-j` flag for JSON output so agents can parse the result programmatically:
  ```json
  { "status": "ok", "repo_url": "https://github.com/user/repo" }
  ```

---

### Phase D — GitHub Actions Support (let agents trigger via workflow dispatch)

- [ ] **D.1** Create `.github/workflows/new-repo.yml` with `workflow_dispatch` trigger and inputs for `project_name`, `github_user`, and `repo_name` — allowing any agent that can call the GitHub API to create a new repo without shell access
- [ ] **D.2** In the workflow, use `${{ secrets.GITHUB_TOKEN }}` (or a PAT stored as a repo secret) so no token is ever passed on the command line
- [ ] **D.3** Add a CI workflow (`.github/workflows/ci.yml`) that runs `shellcheck` on `init.sh` on every push and PR to `main`
- [ ] **D.4** Document the `workflow_dispatch` API call pattern in this file so agents know how to invoke it:
  ```bash
  curl -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/droxey/newproject/actions/workflows/new-repo.yml/dispatches \
    -d '{"ref":"main","inputs":{"project_name":"My Project","github_user":"octocat","repo_name":"my-repo"}}'
  ```

---

### Phase E — Documentation & Validation

- [ ] **E.1** Update `README.md` to document environment variable usage and the `workflow_dispatch` method alongside the existing CLI usage
- [ ] **E.2** Smoke-test the full flow inside a GitHub Codespace (validates devcontainer + env var path)
- [ ] **E.3** Smoke-test the `workflow_dispatch` flow using each agent type to confirm end-to-end usability
- [ ] **E.4** Verify that `grep -r '\[\[' $REPO_DIR` after `cleanup()` returns only `[[PROJECT_DESC]]` and `[[PROJECT_LOGO]]`
