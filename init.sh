#!/bin/bash

while getopts ":h:n:u:r:t:m:" opt; do
  case $opt in
    h) echo "-h"; exit 0
    ;;
    n) PROJECT_NAME="$OPTARG"
    ;;
    u) GITHUB_USER="$OPTARG"
    ;;
    r) GITHUB_REPO="$OPTARG"
    ;;
    t) GITHUB_TOKEN="$OPTARG"
    ;;
    m) FLAVOR="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

function require_var() {
    if [ -z "${!1}" ]; then
        echo "[ERR] Missing required flag: $2" >&2; exit 2
    fi
}

require_var PROJECT_NAME "-n <project-name>"
require_var GITHUB_USER  "-u <github-user>"
require_var GITHUB_REPO  "-r <repo-slug>"
require_var GITHUB_TOKEN "-t <github-token>"

EXEC_DIR=$PWD
if [ -d "$HOME/dev/repos" ]; then
    CLONE_DIR="$HOME/dev/repos"
else
    CLONE_DIR=$EXEC_DIR
fi

if [ -d "$CLONE_DIR/.git" ]; then
    echo "[ERR] Don't run this script in a git repository!"; exit 2
fi

REPO_DIR="$CLONE_DIR/$GITHUB_REPO"
if [ -d "$REPO_DIR" ]; then
    echo "[ERR] $REPO_DIR already exists."; exit 2
fi

REPO_PATH="$GITHUB_USER/$GITHUB_REPO"
REPO_REMOTE="git@github.com:$REPO_PATH"
REPO_URL="https://github.com/$REPO_PATH"

function _copy_to_clipboard() {
    if command -v pbcopy &>/dev/null; then
        echo "$1" | pbcopy
    elif command -v xclip &>/dev/null; then
        echo "$1" | xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
        echo "$1" | xsel --clipboard --input
    fi
}

function _open_url() {
    if command -v open &>/dev/null; then
        open "$1"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$1"
    fi
}

function create() {
    response=$(curl -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/droxey/newproject/generate \
        -d '{"name":"'"$GITHUB_REPO"'","owner":"'"$GITHUB_USER"'"}' \
        --write-out '%{http_code}' --silent --output /dev/null)

    case $response in
        201)
            echo "[NEW] New repo created at $REPO_URL."
            echo
            echo "      - Modify settings for your project: $REPO_URL/settings"
            ;;
        422)
            echo "[ERR] Repo already exists at https://github.com/$REPO_PATH."
            echo
            echo "      - Delete at https://github.com/$REPO_PATH/settings."
            echo "      - Confirmation ($REPO_PATH) copied to clipboard."
            _copy_to_clipboard "$REPO_PATH"
            _open_url "$REPO_URL/settings"
            exit 2
            ;;
        *)
            echo "[ERR] Received $response response when creating repo."; exit 2
            ;;
    esac
}

function clone() {
    git clone --quiet --depth 1 "$REPO_REMOTE" "$REPO_DIR" > /dev/null && rm -rf "$REPO_DIR/.git"
    echo "[NEW] Repository cloned into $REPO_DIR."
}

if [[ "$(uname)" == "Darwin" ]]; then
    SED_INPLACE=(-i '')
else
    SED_INPLACE=(-i)
fi

function parse() {
    find "$REPO_DIR" -type f -exec sed "${SED_INPLACE[@]}" -e "s/$1/${2}/g" {} \;
}

function setup_flavor() {
    local flavor="$1"
    local dockerfile="$REPO_DIR/Dockerfile"
    case $flavor in
        go)
            cat > "$dockerfile" <<'EOF'
# syntax=docker/dockerfile:1
FROM golang:1.23-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o /app/server .

FROM alpine:3.21
WORKDIR /app
COPY --from=build /app/server .
CMD ["/app/server"]
EOF
            ;;
        node)
            cat > "$dockerfile" <<'EOF'
# syntax=docker/dockerfile:1
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .

FROM node:22-alpine
WORKDIR /app
COPY --from=build /app .
CMD ["node", "index.js"]
EOF
            ;;
        python)
            cat > "$dockerfile" <<'EOF'
# syntax=docker/dockerfile:1
FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "main.py"]
EOF
            ;;
        static)
            cat > "$dockerfile" <<'EOF'
# syntax=docker/dockerfile:1
FROM nginx:alpine
COPY . /usr/share/nginx/html
EOF
            ;;
        *)
            echo "[ERR] Unknown flavor: $flavor. Valid options: go, node, python, static." >&2; exit 2
            ;;
    esac
    echo "[NEW] Dockerfile configured for $flavor."
}

function cleanup() {
    mv -f "$REPO_DIR/_README.md" "$REPO_DIR/README.md"
    parse "\[\[PROJECT_NAME\]\]" "$PROJECT_NAME"
    parse "\[\[GITHUB_REPO\]\]"  "$GITHUB_REPO"
    parse "\[\[GITHUB_USER\]\]"  "$GITHUB_USER"

    if [ -n "$FLAVOR" ]; then
        setup_flavor "$FLAVOR"
    fi

    mv -f "$REPO_DIR/.env.sample" "$REPO_DIR/.env"
    rm -f "$REPO_DIR/init.sh"
}

function commit() {
    cd "$REPO_DIR" || exit
    git init --quiet
    git remote add origin "$REPO_REMOTE"
    git add .
    git commit -m "Initial commit"
    git push origin main --force
    cd "$EXEC_DIR" || exit
}

create && clone && cleanup && commit

exit 0
