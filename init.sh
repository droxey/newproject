#!/bin/bash

while getopts ":h:n:u:r:t:" opt; do
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
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

EXEC_DIR=$PWD
if [ -d "$HOME/dev/repos" ]; then
    # Place the cloned project in @droxey's dev/repos directory if it exists.
    CLONE_DIR="$HOME/dev/repos"
else
    # Otherwise clone to the current working directory.
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

echo $PROJECT_NAME
echo $GITHUB_REPO
echo $GITHUB_TOKEN
echo $GITHUB_USER
echo "---"
echo $EXEC_DIR
echo $CLONE_DIR
echo $REPO_DIR
echo "---"
echo $REPO_PATH
echo $REPO_REMOTE
echo $REPO_URL

function create() {
    response=$(curl -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.baptiste-preview+json" \
        https://api.github.com/repos/droxey/newproject/generate \
        -d '{"name":"'$GITHUB_REPO\"',"owner":"'$GITHUB_USER\"} \
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
            echo $REPO_PATH | pbcopy
            open $REPO_URL/settings
            exit 2
            ;;
        *)
            echo "[ERR] Received $response response when creating repo."; exit 2
            ;;
    esac
}

function clone() {
    # Create a shallow clone of the template repository,
    # Delete the .git directory (we'll replace this later).
    git clone --quiet --depth 1 $REPO_REMOTE $REPO_DIR > /dev/null && rm -rf $REPO_DIR/.git
    echo "[NEW] Repository cloned into $REPO_DIR."
}

function parse() {
    find $REPO_DIR -type f -exec sed -i -e "s/$1/${2}/g" {} \;
}

function cleanup() {
    mv -f $REPO_DIR/_README.md $REPO_DIR/README.md
    parse "[[PROJECT_NAME]]" $PROJECT_NAME
    parse "[[GITHUB_REPO]]" $GITHUB_REPO

    mv -f $REPO_DIR/.env.sample $REPO_DIR/.env
    rm -f $REPO_DIR/init.sh
}

function commit() {
    cd $REPO_DIR
    git init --quiet
    git remote add origin $REPO_REMOTE
    git add .
    git commit -m "Initial commit"
    git push origin master --force
    cd $EXEC_DIR
}

create && clone && cleanup && commit

exit 1
