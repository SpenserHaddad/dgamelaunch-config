#!/bin/bash

set -e

source $DGL_CONF_HOME/sh-utils
source $DGL_CONF_HOME/crawl-git.conf

BRANCH=$1
REVISION="$2"
REPO_DIR=$3

echo $@

clone-crawl-ref() {
    CLONE_DIR=$1
    if [[ -d "$REPO_DIR" && -d "$REPO_DIR/.git" ]]; then
        return 0
    fi
    CMDLINE="git clone $CRAWL_GIT_URL $REPO_DIR"
    say "$CMDLINE"
    $CMDLINE
}

update-crawl-ref() {
    say "Updating git repository $REPO_DIR"
    ( cd $REPO_DIR && git checkout -f &&
        git checkout $BRANCH &&
        git pull )
    if [[ -n "$REVISION" ]]; then
        say "Checking out requested revision: $REVISION"
        ( cd $REPO_DIR && git checkout "$REVISION" )
    fi
}

update-submodules() {
    say "NOT Updating git submodules in $REPO_DIR"
    # ( cd $REPO_DIR && git submodule update --init )
}

[[ -n "$BRANCH" ]] || abort-saying "$0: Checkout branch not specified!"
clone-crawl-ref
update-crawl-ref
update-submodules