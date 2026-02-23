<p align="center">
  <strong>newproject</strong><br/>A quick way for <a href="https://github.com/droxey">@droxey</a> to scaffold new GitHub repositories from a template.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/shell-bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/docker-ready-2496ED?style=flat-square&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/docs-docsify-42b983?style=flat-square" alt="Docs: Docsify">
</p>

---

> Bootstrap a new GitHub repository — complete with README, Dockerfile, and Docsify docs — with a single shell command.

## Prerequisites

- `bash`, `curl`, and `git` installed
- A [personal access token](https://github.com/settings/tokens) with `repo` scope

## Get Started

Run `init.sh` to make a new GitHub repo with this template:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/droxey/newproject/main/init.sh) \
  -n "My Go Service" \
  -u your-github-username \
  -r my-go-service \
  -t your-github-token \
  -m go
```

## Flags

| Flag | Env var fallback | Required | Description |
|------|-----------------|----------|-------------|
| `-n` | `NEWPROJECT_NAME` | ✅ | Human-readable project name |
| `-u` | `GITHUB_ACTOR` | ✅ | GitHub username |
| `-r` | `NEWPROJECT_REPO` | ✅ | Repository slug (directory name) |
| `-t` | `GITHUB_TOKEN` | ✅ | GitHub personal access token with `repo` scope |
| `-m` | — | ❌ | Project flavor: `go`, `node`, `python`, or `static` — pre-fills the `Dockerfile` |

### AI agent / CI usage

Set credentials via environment variables to avoid exposing them in the process list or shell history:

```bash
export GITHUB_TOKEN="ghp_…"
export GITHUB_ACTOR="your-github-username"
export NEWPROJECT_NAME="My Go Service"
export NEWPROJECT_REPO="my-go-service"

bash <(curl -fsSL https://raw.githubusercontent.com/droxey/newproject/main/init.sh) -m go
```
