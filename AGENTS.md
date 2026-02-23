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

## `init.sh` — AI Agent Usage Analysis

### Current State: What Works ✅

| Feature | Notes |
|---|---|
| Flag-driven interface (`-n -u -r -t -m`) | All inputs are explicit CLI flags — no interactive prompts. |
| Input validation via `require_var` | Missing flags produce a clear `[ERR]` message and `exit 2`. |
| Cross-platform `sed -i` | `SED_INPLACE` array auto-detects macOS vs. Linux. |
| Cross-platform clipboard/browser helpers | `_copy_to_clipboard` and `_open_url` gracefully no-op in headless environments. |
| Language flavor selection (`-m go\|node\|python\|static`) | Agents can request a specific Dockerfile template without editing files manually. |
| Token replacement (`[[PROJECT_NAME]]`, `[[GITHUB_REPO]]`, `[[GITHUB_USER]]`) | Three of five defined tokens are auto-replaced. |
| Structured `[NEW]` / `[ERR]` prefixes | Output is parseable with basic `grep`/pattern matching. |
| `exit 0` on success | CI/agent orchestrators can reliably detect completion. |

### Current State: What Doesn't Work ❌

| # | Blocker | Location | Impact |
|---|---|---|---|
| B1 | **SSH-only git clone** — uses `git@github.com:` URL; agent sandboxes rarely have SSH keys configured. | `init.sh:50,102` | 🔴 Script fails silently in any headless/containerised agent context without SSH keys. |
| B2 | **No dry-run mode** — the script immediately calls `create()` (GitHub API) and `commit()` (force-push). There is no way to preview or validate without side effects. | `init.sh:200` | 🔴 Agents cannot test or validate invocation without mutating GitHub state. |
| B3 | **`-t` flag exposes the token in the process list** — any `ps aux` call while the script runs reveals `$GITHUB_TOKEN` in the argument vector. | `init.sh:13` | 🔴 Security risk in multi-tenant agent environments (e.g., GitHub-hosted runners). |
| B4 | **No environment-variable fallback for flags** — credentials cannot be injected via `GITHUB_TOKEN=… ./init.sh …`, requiring every caller to pass the token as a CLI argument. | `init.sh:3-20` | 🟠 Agents using repository secrets (Actions, Codespaces) must reconstruct the flag form. |
| B5 | **Hard-coded clone destination** — clones to `$HOME/dev/repos` if that directory exists, otherwise `$PWD`. Agents typically need an explicit, predictable target path. | `init.sh:34-38,44` | 🟠 Output path is non-deterministic; agents cannot reliably reference generated files afterward. |
| B6 | **`git push --force` to `main`** — the initial commit force-pushes the default branch. In protected-branch or fine-grained-token scenarios this will fail with an opaque error. | `init.sh:196` | 🟠 Newer fine-grained personal access tokens (PATs) often disallow force-push. |
| B7 | **No machine-readable success output** — the script produces human-readable prose; there is no JSON or key=value summary for downstream consumers. | `init.sh:82-85` | 🟡 Agents must screen-scrape to know the final repo URL, clone path, or status. |
| B8 | **`-h` flag emits no usage text** — prints the literal string `"-h"` and exits instead of showing a help/usage message. | `init.sh:5` | 🟡 Agents relying on `--help` introspection receive no usable information. |
| B9 | **`init.sh` self-deletes** — `cleanup()` removes itself from the generated repo (`rm -f "$REPO_DIR/init.sh"`). Re-running or debugging the generation step requires re-downloading the script. | `init.sh:187` | 🟡 Acceptable for human users; agents that re-invoke the script after clone will fail to find it. |
| B10 | **`[[PROJECT_DESC]]` and `[[PROJECT_LOGO]]` are never replaced** — generated repos always contain unfilled placeholders in visible locations (`index.html`, `_README.md`, `copilot-instructions.md`). | `init.sh:176-188` | 🟡 Agents operating inside a generated repo may propagate placeholder strings into commits. |

---

### Required Changes to Support Agent-Driven Invocation

#### RC1 — Support HTTPS clone (and env-var token injection)

Replace the SSH remote with an HTTPS remote that embeds the token, and accept `GITHUB_TOKEN` as an environment variable so agents can inject credentials via secrets rather than CLI flags.

```bash
# Use HTTPS with token for agent/CI environments
REPO_REMOTE="https://${GITHUB_TOKEN}@github.com/${REPO_PATH}.git"

# Accept env-var fallback so -t is optional when GITHUB_TOKEN is set
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
# (then require_var still fires if both are absent)
```

#### RC2 — Add a `--dry-run` / `-d` flag

Skip `create()` and `commit()` when `-d` is passed; run only `clone()` and `cleanup()` against a local directory. This lets agents validate token replacement and file structure without touching GitHub.

```bash
# getopts addition
d) DRY_RUN=1 ;;

# main pipeline
if [ -z "$DRY_RUN" ]; then
    create && clone && cleanup && commit
else
    clone && cleanup
fi
```

#### RC3 — Accept an explicit output directory flag (`-o`)

Allow callers to specify exactly where the repo is cloned. Removes the `$HOME/dev/repos` heuristic.

```bash
o) CLONE_DIR="$OPTARG" ;;
```

#### RC4 — Emit a structured summary on success

After a successful run, write a key=value (or JSON) block to stdout so agents can parse results without screen-scraping prose.

```bash
# At end of successful pipeline
echo "REPO_URL=$REPO_URL"
echo "REPO_DIR=$REPO_DIR"
echo "FLAVOR=${FLAVOR:-default}"
```

#### RC5 — Fix `-h` to emit real usage text

```bash
h)
    echo "Usage: init.sh -n <name> -u <user> -r <repo> -t <token> [-m go|node|python|static] [-d] [-o <dir>]"
    exit 0
    ;;
```

#### RC6 — Replace force-push with a branch-safe push

```bash
# Replace: git push origin main --force
# With:
git push -u origin main
```

---

### Prioritized TODO Checklist

> Items are ordered by severity of agent-blocking impact. Security issues are addressed first.

- [ ] **P0 — Security** `[B3]` Move token out of process-argument vector: accept `GITHUB_TOKEN` env var; keep `-t` as an optional override that writes to the variable, not to the argument list directly.
- [ ] **P1 — Correctness** `[B1]` Switch git clone and remote URLs from SSH (`git@github.com:`) to HTTPS (`https://github.com/`) with token embedding, so the script works in any containerized or sandboxed agent environment.
- [ ] **P1 — Correctness** `[B6]` Replace `git push origin main --force` with `git push -u origin main` to respect branch protection rules and fine-grained PAT restrictions.
- [ ] **P2 — Testability** `[B2]` Add a `-d` (dry-run) flag that skips `create()` and `commit()` so agents (and humans) can validate token replacement locally without mutating GitHub state.
- [ ] **P2 — Reliability** `[B5]` Add a `-o <dir>` flag for an explicit clone destination; remove the `$HOME/dev/repos` auto-detection heuristic.
- [ ] **P3 — Integration** `[B4]` Accept all four credentials (`GITHUB_TOKEN`, `GITHUB_USER`, `GITHUB_REPO`, `PROJECT_NAME`) as environment variable fallbacks so agents using repository secrets don't need to reconstruct CLI flags.
- [ ] **P3 — Integration** `[B7]` Emit a structured `KEY=VALUE` summary block at the end of a successful run so agent orchestrators can parse `REPO_URL` and `REPO_DIR` without screen-scraping.
- [ ] **P4 — UX** `[B8]` Replace the `-h` stub with a real usage/help message listing all flags, defaults, and examples.
- [ ] **P4 — UX** `[B10]` Document clearly (here and in `copilot-instructions.md`) that `[[PROJECT_DESC]]` and `[[PROJECT_LOGO]]` require a manual post-generation step; optionally prompt for them interactively when not in dry-run mode.
- [ ] **P5 — Maintenance** `[B9]` Consider keeping `init.sh` in the generated repo (or replacing its content with a no-op stub) instead of deleting it, to allow re-generation or debugging.
