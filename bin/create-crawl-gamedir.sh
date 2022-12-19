#! /bin/bash

# shellcheck source=crawl-git.conf
source "$DGL_CONF_HOME/crawl-git.conf"

set -e
GAME_DIR=$CRAWL_GAMEDIR
echo "Crawl basedir to create: $GAME_DIR"

[[ -d "$GAME_DIR" ]] && abort-saying "Crawl base directory already exists"
assert-chroot-exists
[[ "$UID" != "0" ]] && abort-saying "This script must be run as root"

# ensure some basic preconditions.
# TODO: perhaps do these unconditionally? It's not very risky. In fact, one
# could pretty safely just run this entire script unconditionally.
mkdir -p "$DGL_CHROOT/cores"
mkdir -p "$CHROOT_CRAWL_BASEDIR" \
         "$CHROOT_WEBDIR/" \
         "$CHROOT_WEBDIR/run/" \
         "$CHROOT_WEBDIR/sockets/" \
         "$CHROOT_WEBDIR/templates/" \
         "$CHROOT_DGLDIR/data" \
         "$CHROOT_SAVE_DUMPDIR" \
         "$CHROOT_MORGUEDIR" \
         "$CHROOT_RCFILESDIR" \
         "$CHROOT_TTYRECDIR" \
         "$CHROOT_MENUSDIR" \
         "$CHROOT_INPROGRESSDIR" \
touch "$DGL_CHROOT/dgamelaunch" "$DGL_CHROOT/dgldebug.log"
echo "Own $DGLDIR and $CHROOT_CRAWL_BASEDIR"
chown -R $CRAWL_UGRP "$DGL_CHROOT/dgldebug.log" "$DGLDIR" "$CHROOT_CRAWL_BASEDIR"

mkdir -p "$GAME_DIR"/saves/{sprint,zotdef}
( cd "$GAME_DIR/saves" &&
    touch logfile{,-sprint,-zotdef} \
        milestones{,-sprint,-zotdef} \
        scores{,-sprint,-zotdef} )

# Only the saves dir within GAME_DIR is chowned: data dir is not supposed
# to be writable by CRAWL_UGRP.
chown -R $CRAWL_UGRP "$GAME_DIR/saves"

echo "Created $GAME_DIR"
