# PLAN.md — `newproject` Template Improvement Plan

> **Author:** Senior Software Architect review of [`droxey/newproject`](https://github.com/droxey/newproject)
> **Date:** 2026-02-23
> **Based on:** repository history, active GitHub projects, coding patterns across droxey's public repos

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Current State Analysis](#2-current-state-analysis)
3. [Key Files & Annotated Snippets](#3-key-files--annotated-snippets)
   - [init.sh](#31-initsh)
   - [index.html](#32-indexhtml)
   - [_README.md Template](#33-_readmemd-template)
4. [Improvement Themes](#4-improvement-themes)
5. [Risks, Mitigations & Verification](#5-risks-mitigations--verification)
6. [Phased TODO List](#6-phased-todo-list)
   - [Phase 1 — Harden the Shell Script](#phase-1--harden-the-shell-script)
   - [Phase 2 — Expand Token Replacement](#phase-2--expand-token-replacement)
   - [Phase 3 — GitHub Actions & Developer Experience](#phase-3--github-actions--developer-experience)
   - [Phase 4 — Docsify & Documentation Polish](#phase-4--docsify--documentation-polish)
   - [Phase 5 — AI-Native Tooling Integration](#phase-5--ai-native-tooling-integration)
   - [Phase 6 — Validation & Release](#phase-6--validation--release)

---

## 1. Architecture Overview

`newproject` is a single-file Bash bootstrapper that:

```
User runs init.sh
      │
      ▼
  Parse flags (-n, -u, -r, -t)
      │
      ▼
  GitHub API → Create repo from template (droxey/newproject)
      │
      ▼
  git clone → shallow depth 1
      │
      ▼
  sed token replacement ([[PROJECT_NAME]], [[GITHUB_REPO]])
      │
      ▼
  Rename _README.md → README.md, .env.sample → .env
      │
      ▼
  git init + push to main
```

**Ecosystem signals from droxey's active repos (2025–2026):**

| Pattern | Repos |
|---|---|
| Go CLIs and microservices | `gopherology`, `graindl`, `getpunk`, `strainscan` |
| Docker + CapRover deployment | `clincher`, `caprover-workadventure`, `docker-flask-sqlalchemy` |
| AI agents / OpenClaw skills | `agentadventure`, `ai`, `prompts` |
| Docsify documentation | `tocsify` (npm module), `newproject` |
| Shell scripting + dotfiles | `dotfiles`, `caprover-workadventure-livekit` |
| GitHub Copilot Coding Agent usage | `newproject`, `skills-expand-your-team-with-copilot` |

The template should reflect these patterns while remaining universally useful.

---

## 2. Current State Analysis

### Strengths
- Minimal dependency surface (`bash`, `curl`, `git` only)
- Docsify docs require zero build step
- `[[TOKEN]]` convention is simple and consistent
- CapRover-ready via `captain-definition`

### Weaknesses

| # | Issue | Location | Severity |
|---|---|---|---|
| 1 | Debug `echo` statements leak secrets (`$GITHUB_TOKEN`) to stdout | `init.sh:42-53` | 🔴 Critical |
| 2 | `exit 1` at end of successful run signals failure | `init.sh:116` | 🔴 Critical |
| 3 | macOS-only commands (`pbcopy`, `open`) make script non-portable | `init.sh:74-75` | 🟠 High |
| 4 | Deprecated GitHub API preview header (`baptiste-preview`) | `init.sh:58` | 🟠 High |
| 5 | `[[PROJECT_DESC]]`, `[[PROJECT_LOGO]]`, `[[GITHUB_USER]]` tokens never replaced | `init.sh:97-98` | 🟡 Medium |
| 6 | No input validation — empty flags silently produce corrupt repos | `init.sh:3-18` | 🟡 Medium |
| 7 | `hasValue()` in `index.html` logic is inverted (checks if value IS a placeholder) | `index.html:19-21` | 🟡 Medium |
| 8 | No GitHub Actions workflow for any CI/CD | `.github/` | 🟡 Medium |
| 9 | No issue/PR templates | `.github/` | 🟢 Low |
| 10 | No `.devcontainer` for Codespaces / Copilot agent contexts | — | 🟢 Low |
| 11 | `docs/_sidebar.md` and `docs/_navbar.md` are empty | `docs/` | 🟢 Low |
| 12 | No `[[GITHUB_USER]]` token replacement means Docsify repo link is always `droxey/…` | `index.html:26` | 🟡 Medium |

---

## 3. Key Files & Annotated Snippets

### 3.1 `init.sh`

**Problem 1 — token leak + wrong exit code:**

```bash
# CURRENT (lines 42-53, 116) — BROKEN
echo $PROJECT_NAME      # leaks to stdout
echo $GITHUB_TOKEN      # ⚠️  leaks secret!
# ...
exit 1                  # ❌ signals failure even on success

# PROPOSED
# Remove all debug echo lines entirely.
# Replace final `exit 1` with `exit 0`.
```

**Problem 2 — macOS-only commands:**

```bash
# CURRENT (lines 74-75)
echo $REPO_PATH | pbcopy   # macOS only
open $REPO_URL/settings    # macOS only

# PROPOSED — cross-platform clipboard helper
function _copy_to_clipboard() {
    if command -v pbcopy &>/dev/null; then
        echo "$1" | pbcopy
    elif command -v xclip &>/dev/null; then
        echo "$1" | xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
        echo "$1" | xsel --clipboard --input
    fi
}
```

**Problem 3 — deprecated API header:**

```bash
# CURRENT
-H "Accept: application/vnd.github.baptiste-preview+json" \

# PROPOSED (current stable header as of 2024)
-H "Accept: application/vnd.github+json" \
-H "X-GitHub-Api-Version: 2022-11-28" \
```

**Problem 4 — missing input validation:**

```bash
# PROPOSED — add after getopts block
function require_var() {
    if [ -z "${!1}" ]; then
        echo "[ERR] Missing required flag: $2" >&2; exit 2
    fi
}
require_var PROJECT_NAME "-n <project-name>"
require_var GITHUB_USER  "-u <github-user>"
require_var GITHUB_REPO  "-r <repo-slug>"
require_var GITHUB_TOKEN "-t <github-token>"
```

**Problem 5 — incomplete token replacement:**

```bash
# CURRENT (lines 97-98)
parse "[[PROJECT_NAME]]" $PROJECT_NAME
parse "[[GITHUB_REPO]]"  $GITHUB_REPO

# PROPOSED — replace ALL defined tokens
parse "\[\[PROJECT_NAME\]\]" "$PROJECT_NAME"
parse "\[\[GITHUB_REPO\]\]"  "$GITHUB_REPO"
parse "\[\[GITHUB_USER\]\]"  "$GITHUB_USER"
```

> `[[PROJECT_DESC]]` and `[[PROJECT_LOGO]]` intentionally remain as manual placeholders; they are project-specific.

---

### 3.2 `index.html`

**Problem — inverted `hasValue` guard:**

```js
// CURRENT (line 19-21) — checks if value IS still a placeholder
var hasValue = function(value) {
  return value.startsWith('[[') && value.endsWith(']]');
}
// Used as: customLogo = hasValue(projectLogo) ? projectLogo : fallback
// BUG: this uses the placeholder string AS the logo, not the fallback

// PROPOSED — rename to isPlaceholder, invert usage
var isPlaceholder = function(value) {
  return value.startsWith('[[') && value.endsWith(']]');
}
const customLogo = isPlaceholder(projectLogo)
  ? 'https://droxey.com/statics/img/logo-large.png'
  : projectLogo;
```

**Problem — hardcoded `droxey/` repo prefix:**

```js
// CURRENT (line 26)
repoNameFull = 'droxey/' + repoName,

// PROPOSED — use replaced [[GITHUB_USER]] token
repoOwner    = '[[GITHUB_USER]]',
repoNameFull = repoOwner + '/' + repoName,
```

---

### 3.3 `_README.md` Template

**Proposed additions** — skeleton sections that every droxey project needs:

```markdown
## Features

- [ ] Feature 1
- [ ] Feature 2

## Development

```bash
cp .env.sample .env   # copy and edit environment variables
```

## Deployment

> Deployed via [CapRover](https://caprover.com). See `captain-definition`.

## License

[MIT](LICENSE) © [[GITHUB_USER]]
```

---

## 4. Improvement Themes

Based on droxey's active 2025–2026 GitHub work, five improvement themes emerge:

### Theme A — Script Hardiness
Fix the token leak, wrong exit code, macOS-only commands, and missing validation. These are bugs, not enhancements.

### Theme B — Complete Token Coverage
`[[GITHUB_USER]]` and `[[PROJECT_DESC]]` should flow through the Docsify `index.html` and README so the generated project has zero `droxey` references.

### Theme C — GitHub Actions CI
Every active droxey project uses GitHub Actions. The template should include a starter `.github/workflows/ci.yml` that runs `shellcheck` on `init.sh` and validates the template structure. Future generated repos can replace this with their own pipeline.

### Theme D — AI-Native Developer Experience
Given droxey's heavy use of GitHub Copilot (Copilot Coding Agent, OpenClaw skills), the template should include a `.github/copilot-instructions.md` stub and a `.devcontainer/devcontainer.json` so any cloned project is immediately Codespaces- and Copilot Agent-ready.

### Theme E — Docsify Quality
The `docs/_sidebar.md` and `docs/_navbar.md` are empty. A minimal populated scaffold improves the out-of-the-box Docsify experience.

---

## 5. Risks, Mitigations & Verification

| Risk | Likelihood | Impact | Mitigation | Verification |
|---|---|---|---|---|
| `sed -i` behaves differently on macOS vs Linux (requires `-i ''` on macOS) | High | Medium | Detect OS and pass correct `sed -i` flag; or use `perl -pi -e` which is portable | Run `init.sh` on both macOS and Ubuntu (act or GitHub Actions matrix) |
| GitHub API format/version header changes break `create()` | Medium | High | Pin `X-GitHub-Api-Version: 2022-11-28`; add HTTP status logging | Test with `curl -v` against the live API in CI |
| Expanding token replacement breaks files with literal `[[` brackets | Low | Low | Tokens are scoped to `[[A-Z_]+]]` pattern; unlikely to collide in code | Review generated output in Phase 6 verification step |
| `.devcontainer` bloats every generated project | Low | Low | Keep `devcontainer.json` minimal (use a prebuilt image, no extensions list) | Review file size; keep under 20 lines |
| `shellcheck` failures on existing `init.sh` break CI | High | Low | Fix all `shellcheck` warnings as part of Phase 1 | `shellcheck init.sh` passes with zero warnings |
| Removing debug `echo` statements hides useful progress output | Low | Low | Replace with intentional `[INFO]` lines for non-sensitive variables only | Manual test run review |

---

## 6. Phased TODO List

---

### Phase 1 — Harden the Shell Script

> Goal: Fix all bugs, make the script POSIX-portable and `shellcheck`-clean.

- [x] **1.1** Remove all debug `echo` statements (`lines 42–53` in `init.sh`)
- [x] **1.2** Replace `exit 1` at end of script with `exit 0`
- [x] **1.3** Add `require_var` input validation function after `getopts` block
- [x] **1.4** Update GitHub API `Accept` header from `baptiste-preview` to `application/vnd.github+json` and add `X-GitHub-Api-Version: 2022-11-28`
- [x] **1.5** Replace `pbcopy` / `open` with cross-platform `_copy_to_clipboard` and `_open_url` helpers
- [x] **1.6** Fix `sed -i` portability: detect macOS (`darwin`) and use `sed -i ''`; use `sed -i` on Linux
- [x] **1.7** Double-quote all variable expansions in `parse`, `clone`, `commit` functions
- [x] **1.8** Run `shellcheck init.sh` and fix all warnings to zero

---

### Phase 2 — Expand Token Replacement

> Goal: All `[[TOKEN]]` occurrences are resolved for the tokens init.sh knows about.

- [x] **2.1** Add `parse "[[GITHUB_USER]]" "$GITHUB_USER"` to `cleanup()` in `init.sh`
- [x] **2.2** Fix `hasValue` → `isPlaceholder` logic inversion in `index.html` (lines 19–27)
- [x] **2.3** Replace hardcoded `'droxey/'` prefix in `index.html` with `'[[GITHUB_USER]]/'`
- [x] **2.4** Verify `_README.md` uses `[[GITHUB_USER]]` in the license line and any author references
- [x] **2.5** Update `index.html` `<meta name="author">` to use `[[GITHUB_USER]]` instead of hardcoded `dani@bitoriented.com`
- [x] **2.6** Smoke-test: after `cleanup()` runs, `grep -r '\[\[' $REPO_DIR` should return only `[[PROJECT_DESC]]` and `[[PROJECT_LOGO]]`

---

### Phase 3 — GitHub Actions & Developer Experience

> Goal: Every generated repo starts with CI and is Codespaces-ready.

- [x] **3.1** Create `.github/workflows/ci.yml` in the template that:
  - Runs `shellcheck` on any `*.sh` files found
  - Validates that no `[[TOKEN]]` placeholders remain in non-template files
  - Triggers on `push` and `pull_request` to `main`
- [x] **3.2** Create `.github/ISSUE_TEMPLATE/bug_report.md` with standard fields
- [x] **3.3** Create `.github/ISSUE_TEMPLATE/feature_request.md` with standard fields
- [x] **3.4** Create `.github/pull_request_template.md`
- [x] **3.5** Create `.devcontainer/devcontainer.json` using `mcr.microsoft.com/devcontainers/universal:2` image
- [x] **3.6** Add `.github/copilot-instructions.md` stub with `[[PROJECT_NAME]]` / `[[PROJECT_DESC]]` tokens so Copilot has context for each generated project

---

### Phase 4 — Docsify & Documentation Polish

> Goal: A generated project has a working Docsify site with zero placeholder stubs.

- [x] **4.1** Populate `docs/_sidebar.md` with a minimal nav skeleton (Overview, Quick Start, API/Docs, Contributing)
- [x] **4.2** Populate `docs/_navbar.md` with links to `[[GITHUB_REPO]]` and GitHub repo
- [x] **4.3** Add `[[PROJECT_NAME]]` and `[[PROJECT_DESC]]` tokens to `_sidebar.md` and `_navbar.md` so they are replaced on generation
- [x] **4.4** Add a `docs/overview.md` starter page with `[[PROJECT_DESC]]` content
- [x] **4.5** Expand `_README.md` template: add Features checklist, Development section, Deployment (CapRover) section, License line with `[[GITHUB_USER]]`
- [x] **4.6** Pin Docsify CDN scripts in `index.html` to specific semver ranges instead of `@0` / latest to prevent breaking changes
- [x] **4.7** Fix unclosed `<script>` tag in `index.html` (line 92 opens `<script>` with no content, line 93 closes `</body>` — missing `</script>`)

---

### Phase 5 — AI-Native Tooling Integration

> Goal: Support droxey's active AI-agent and Copilot-heavy workflow.

- [x] **5.1** Add an `AGENTS.md` or `.github/copilot-instructions.md` that explains the `[[TOKEN]]` system to Copilot / AI agents operating inside generated repos
- [x] **5.2** Add a `CONTRIBUTING.md` template stub that references Copilot coding agent conventions
- [x] **5.3** Consider adding an optional `-m` flag to `init.sh` for selecting a "flavor" (e.g., `go`, `node`, `python`, `static`) that copies a language-specific `Dockerfile` stub
- [x] **5.4** Add a `Makefile` stub with common targets (`help`, `dev`, `build`, `deploy`) so Copilot agent can discover project entry points
- [x] **5.5** Evaluate adding an `.openclaw/skill.json` stub for OpenClaw skill scaffolding (given `agentadventure` / `clincher` patterns)

---

### Phase 6 — Validation & Release

> Goal: Confirm everything works end-to-end before tagging `v2.0.0`.

- [x] **6.1** Run `shellcheck init.sh` — must pass with zero warnings
- [ ] **6.2** Run `init.sh` in dry-run mode against a test GitHub org and verify:
  - Repo created successfully (HTTP 201)
  - All `[[TOKEN]]` placeholders replaced except `[[PROJECT_DESC]]` and `[[PROJECT_LOGO]]`
  - `README.md` present, `_README.md` absent
  - `.env` present, `.env.sample` absent
  - `init.sh` absent from generated repo
  - Docsify site loads in browser with correct project name
- [ ] **6.3** Test on both macOS and Linux (Ubuntu via GitHub Actions matrix)
- [x] **6.4** Update `README.md` in `newproject` itself to reflect new flags and capabilities
- [ ] **6.5** Tag release `v2.0.0` with changelog summarizing all changes
- [x] **6.6** Update `init.sh` curl install command in README to point to `main` branch (already done; verify)
