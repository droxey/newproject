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
     -n "My Project Name" \
     -u your-github-username \
     -r your-repo-name \
     -t your-github-token
   ```
