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
