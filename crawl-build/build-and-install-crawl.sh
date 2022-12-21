#!/bin/bash

set -e
lock-or-die crawl-update "someone is already updating the crawl build"

source "$DGL_CONF_HOME/crawl-git.conf"
check-versions-db-exists

export DESTDIR=$CRAWL_BASEDIR

check-crawl-basedir-exists
# enable-prompts "$*"

INSTALL_WEBSERVER="0"

# Handle input arguments
while getopts r:v:w flag; do
    case "${flag}" in
        r) REVISION=${OPTARG}; echo "rev is $REVISION";;
        v) VERSION=${OPTARG}; echo "ver is ${OPTARG}";;
        w) INSTALL_WEBSERVER="1";;
        *) echo "Invalid argument $flag"; exit 1
    esac 
done

if [[ -n "$VERSION" ]]; then
    if [[ $VERSION != [0-9]* ]]; then
        BRANCH=$VERSION
    else
        BRANCH=stone_soup-$VERSION
    fi
else
    VERSION="git"
    BRANCH="master"
fi

GAME="crawl-$VERSION"

if [[ -z "$REVISION" ]]; then
    REVISION="HEAD"
else
    GAME="$GAME-$REVISION"
fi

# First argument can be a revision (SHA) to build
REPO_DIR="$CRAWL_REPO_ROOT-$BRANCH"
echo "branch=$BRANCH, version=$VERSION, rev=$REVISION, repo_dir=$REPO_DIR"

# Clone the repository
./update-public-repository.sh "$BRANCH" "$REVISION" "$REPO_DIR"

REVISION="$(git -C "$REPO_DIR" rev-parse HEAD | cut -c 1-10)"
REVISION_FULL="$(git -C "$REPO_DIR" describe --always --long HEAD)"
REVISION_OLD="$(echo "select hash from versions order by time desc limit 1;" | sqlite3 "${VERSIONS_DB}")"

echo "revision=$REVISION, rev_full=$REVISION_FULL, rev_old=$REVISION_OLD"

# [[ "$REVISION" == "$REVISION_OLD" ]] && \
#     abort-saying "Nothing new to install at the moment: you asked for $REVISION_FULL and it's already installed"

prompt "start update build"

cd "$REPO_DIR/crawl-ref"

echo "Copying CREDITS to docs/crawl_credits.txt..."
cp CREDITS.txt docs/crawl_credits.txt

dgl-git-log() {
    header="$(printf '%*s' 80 "" | tr ' ' '-')"
    git -C "$REPO_DIR" log --pretty=tformat:"$header%n%h | %an | %ci%n%n%s%n%b" "$@" | grep -v "git-svn-id" | awk 1 RS= ORS="\n\n" | fold -s
}

echo "Creating changelog in docs/crawl_changelog.txt..."
dgl-git-log "$BRANCH" > docs/crawl_changelog.txt

if prompts-enabled; then
    echo "Changes to $BRANCH from $REVISION_OLD .. $REVISION"
    dgl-git-log "${REVISION_OLD}..${REVISION}" | less
fi

# Compile the Crawl version
prompt "compile ${GAME}-${REVISION}"
(say-do nice make -j4 -C source \
    GAME="${GAME}" \
    GAME_MAIN="${GAME}" \
    MCHMOD=0755 \
    MCHMOD_SAVEDIR=755 \
    INSTALL_UGRP="${CRAWL_UGRP}" \
    WEBTILES=YesPlease \
    USE_DGAMELAUNCH=YesPlease \
    WIZARD=YesPlease \
    LTO=yes \
    STRIP=true \
    DESTDIR="${DESTDIR}" \
    prefix= \
    bin_prefix=/bin \
    SAVEDIR=$CHROOT_CRAWL_BASEDIR/${GAME}/saves \
    DATADIR=$CHROOT_CRAWL_BASEDIR/${GAME}/data \
    WEBDIR=$CHROOT_CRAWL_BASEDIR/${GAME}/data/web \
    SHAREDDIR=$CHROOT_CRAWL_BASEDIR/${GAME}/saves \
    USE_PCRE=y \
    EXTERNAL_FLAGS_L="-g"
)

prompt "install ${GAME}"

if [[ "$(uname)" != "Darwin" ]] && {
        ps -fC "${GAME}" |
        awk '{ print $1" "$2"\t "$5" "$7"\t "$8" "$9" "$10 }' |
        grep ^"$DGL_USER";
    }
then
    abort-saying "There are already active instances of this version (${REVISION_FULL}) running"
fi

echo "Searching for version tags..."
SGV_MAJOR=$($CRAWL_BUILD_DIR/crawl-tag-major-version.sh)
[[ -n "$SGV_MAJOR" ]] || abort-saying "Couldn't find save major version"
echo "Save major version: $SGV_MAJOR"
SGV_MINOR="0"

say-do sudo -H "$DGL_CHROOT/sbin/install-crawl.sh" \
    "$REVISION" \
    "$REVISION_FULL" \
    "$SGV_MAJOR" \
    "$SGV_MINOR" \
    "$VERSION" \
    "$GAME" \
    "$INSTALL_WEBSERVER" \
    "0"

announce "Installed new Crawl version on $DGL_SERVER: ${REVISION_FULL} (${SGV_MAJOR})"

echo "All done."
echo
