# GitHub Copilot Instructions

## Project Overview

`newproject` is a Bash-based scaffolding tool that bootstraps new GitHub repositories from a template. It uses the GitHub API to generate a new repo from the `droxey/newproject` template, clones it locally, replaces placeholder tokens in template files, and pushes the initial commit.

## Repository Structure

- `init.sh` — Main entry point. Parses CLI flags, calls the GitHub API to create the repo, clones it, runs token replacement, and pushes the initial commit.
- `_README.md` — Template README copied to `README.md` in the generated project. Uses `[[PLACEHOLDER]]` tokens replaced at generation time.
- `index.html` — Docsify-powered documentation shell. Also uses `[[PLACEHOLDER]]` tokens.
- `Dockerfile` — Empty Docker starter file included in every generated project.
- `docs/` — Docsify sidebar and navbar stubs.
- `.env.sample` — Copied to `.env` in generated projects; add environment variable keys here.

## Template Tokens

Tokens in the form `[[TOKEN_NAME]]` are replaced by `init.sh` at generation time using `sed`:

| Token | Replaced With |
|---|---|
| `[[PROJECT_NAME]]` | Human-readable project name (`-n` flag) |
| `[[GITHUB_REPO]]` | Repository slug / directory name (`-r` flag) |
| `[[GITHUB_USER]]` | GitHub username (`-u` flag) |
| `[[PROJECT_DESC]]` | Short project description (filled in manually after generation) |
| `[[PROJECT_LOGO]]` | URL to project logo (filled in manually after generation) |

## Coding Conventions

- **Shell**: POSIX-compatible Bash. Use `function name()` syntax, double-quote all variable expansions.
- **Error handling**: Print `[ERR] <message>` to stderr and `exit 2` on failure. Print `[NEW] <message>` for successful creation steps.
- **curl**: Use `--silent` with `--write-out '%{http_code}'` to capture HTTP status codes without body output.
- **Git**: Default branch is `main`.
- **Docker**: Keep the `Dockerfile` minimal; the consuming project fills it in.
- **Docs**: Documentation is powered by [Docsify](https://docsify.js.org). Do not add build steps — it runs entirely in the browser.

## Style

- Keep `init.sh` as a single self-contained script with no external dependencies beyond `bash`, `curl`, and `git`.
- Prefer simple, readable shell constructs over clever one-liners.
- README files follow the centered-header + badge + `---` divider format defined in `_README.md`.
