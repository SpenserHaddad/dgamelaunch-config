#!/bin/bash
#
# This script needs a sudo entry for user crawl to run as root:
# For obvious reasons, this script should not source any other scripts that
# are not owned by root.
#
# ===========================================================================
# Copyright (C) 2008, 2009, 2010, 2011 Marc H. Thoben
# Copyright (C) 2011 Darshan Shaligram
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
# ===========================================================================
#

set -e
set -u
shopt -s extglob

# These are not overrideable:
CHROOT="%%DGL_CHROOT%%"
CHROOT_BINARIES="%%CHROOT_CRAWL_BINARY_PATH%%"
CHROOT_CRAWL_BASEDIR="%%CHROOT_CRAWL_BASEDIR%%"
CHROOT_DGLDIR="%%CHROOT_DGLDIR%%"
VERSIONS_DB="%%VERSIONS_DB%%"
CRAWL_UGRP="%%CRAWL_UGRP%%"
DGL_SETTINGS_DIR="%%DGL_SETTINGS_DIR%%"
SAVE_DIR="%%SAVEDIR%%"

REVISION="$1"
DESCRIPTION="$2"
SGV_MAJOR="$3"
SGV_MINOR="$4"
VERSION="$5"
GAME="$6"
INSTALL_WEBSERVER="$7"
SET_LATEST="$8" # If set, indicates this should be treated as the "latest" Crawl version

# Safe path:
PATH=/bin:/sbin:/usr/bin:/usr/sbin

if [[ "$UID" != "0" ]]; then
    echo "$0 must be run as root"
    exit 1
fi

copy-game-binary() {
    echo "Installing game binary ($GAME_BINARY) in $BINARIES_DIR"
    mkdir -p $BINARIES_DIR

    if [[ -f $BINARIES_DIR/$GAME_BINARY ]]; then
        mv $BINARIES_DIR/$GAME_BINARY $BINARIES_DIR/$GAME_BINARY.old
    fi

    if cp source/$GAME_BINARY $BINARIES_DIR; then
        rm $BINARIES_DIR/$GAME_BINARY.old || true
    else
        local ERR=$?
        mv $BINARIES_DIR/$GAME_BINARY.old $BINARIES_DIR/$GAME_BINARY || true
        return $ERR
    fi
    
    if [[ $SET_LATEST ]]; then
        ln -sf $GAME_BINARY $BINARIES_DIR/crawl-latest
    fi
}

copy-data-files() {
    echo "Copying game data files to $DATADIR"
    cp -r source/dat docs settings "$DATADIR"
    # Only one of these exists, don't error for the other.
    cp -r README.txt README.md "$DATADIR" 2>/dev/null || true
    cp -r settings/. $DGL_SETTINGS_DIR/$GAME-settings

    mkdir -p "$ABS_COMMON_DIR/data/docs"
    cp docs/crawl_changelog.txt "$ABS_COMMON_DIR/data/docs"
}

link-logfiles() { 
    for file in logfile milestones scores; do
        ln -sf $COMMON_DIR/saves/$file $SAVEDIR
        ln -sf $COMMON_DIR/saves/$file-sprint $SAVEDIR
        ln -sf $COMMON_DIR/saves/$file-zotdef $SAVEDIR
    done
}

create-dgl-directories() {
    mkdir -p "%%CHROOT_INPROGRESSDIR%%/crawl-$VERSION-sprint/"
    mkdir -p "%%CHROOT_INPROGRESSDIR%%/crawl-$VERSION-tut/"
    mkdir -p "%%CHROOT_INPROGRESSDIR%%/crawl-$VERSION-zotdef/"
    mkdir -p "%%CHROOT_INPROGRESSDIR%%/crawl-$VERSION/"
    mkdir -p "%%CHROOT_RCFILESDIR%%/$GAME/"
    mkdir -p $DGL_SETTINGS_DIR/$GAME-settings
}

fix-chroot-directory-permissions() {
    chown -R $CRAWL_UGRP "$CHROOT_CRAWL_BASEDIR"
    chown -R $CRAWL_UGRP "$CHROOT_DGLDIR"
}

install-game() {
    mkdir -p $SAVEDIR/{,sprint,zotdef}
    mkdir -p $DATADIR

    create-dgl-directories
    fix-chroot-directory-permissions
    copy-game-binary
    copy-data-files

    if [[ $SET_LATEST ]]; then
        echo "Setting latest version to $GAME"
        link-logfiles
    fi
    chown -R $CRAWL_UGRP $SAVEDIR

}

install-webserver() {
    cp -r source/webserver/game_data/. "$DATADIR"/web
    cp -r source/webserver/!(config.py|game_data|templates) $WEBDIR
    cp source/webserver/templates/client.html $WEBDIR/templates/
    cp source/webserver/templates/game_links.html $WEBDIR/templates/

    # AFAIK current server admins have customizations in these files, so only
    # copy the other templates over if they're not already present.
    cp --no-clobber source/webserver/templates/*.html $WEBDIR/templates/
}

register-game-version() {
    echo
    echo "Adding version (${SGV_MAJOR}.${SGV_MINOR}) to database..."
    # NOTE: fields not mentioned will be replaced, not updated!
    sqlite3 ${VERSIONS_DB} <<SQL
INSERT OR REPLACE INTO VERSIONS VALUES ('${REVISION}', '$DESCRIPTION', $(date +%s),
                             ${SGV_MAJOR}, ${SGV_MINOR}, 1);
SQL
}

assert-not-evil() {
    local file=$1
    if [[ "$file" != "$(echo "$file" |
                        perl -lpe 's{[.]{2}|[^.a-zA-Z0-9_/-]+}{}g')" ]]
    then
        echo -e "Path $file contains characters I don't like, aborting."
        exit 1
    fi
}

assert-all-variables-exist() {
    local -a broken_variables=()
    for variable_name in "$@"; do
        eval "value=\"\$$variable_name\""
        if [[ -z "$value" ]]; then
            broken_variables=(${broken_variables[@]} $variable_name)
        fi
    done
    if (( ${#broken_variables[@]} > 0 )); then
        echo -e "These variables are required, but are unset:" \
            "${broken_variables[@]}"
        exit 1
    fi
}

if [[ -z "$REVISION" ]]; then
    echo -e "Missing revision argument"
    exit 1
fi

assert-not-evil "$REVISION"

if [[ ! ( "$CRAWL_UGRP" =~ ^[a-z0-9]+:[a-z0-9]+$ ) ]]; then
    echo -e "Expected CRAWL_UGRP to be user:group, but got $CRAWL_UGRP"
    exit 1
fi

if [[ -n "${SGV_MAJOR}" && -n "${SGV_MINOR}" ]]; then
    # COMMON_DIR is the absolute path *inside* the chroot jail of the
    # directory holding common data for all game versions, viz: saves.
    COMMON_DIR=$CHROOT_CRAWL_BASEDIR/$GAME
    assert-not-evil "$COMMON_DIR"

    # ABS_COMMON_DIR is the absolute path from outside the chroot
    # corresponding to COMMON_DIR
    ABS_COMMON_DIR=$CHROOT_CRAWL_BASEDIR/$GAME

    if [[ ! -d "$COMMON_DIR" ]]; then
        mkdir -p "$ABS_COMMON_DIR"
    fi

    GAME_BINARY=$GAME
    BINARIES_DIR=$CHROOT$CHROOT_BINARIES

    WEBDIR=$CHROOT_CRAWL_BASEDIR/webserver
    GAMEDIR=$CHROOT_CRAWL_BASEDIR/$GAME_BINARY
    # Absolute path to save game directory
    SAVEDIR=$CHROOT/$CHROOT_DGLDIR/$GAME_BINARY/saves
    DATADIR=$GAMEDIR/data
    assert-not-evil "$SAVEDIR"
    assert-not-evil "$DATADIR"

    echo "Installing game"
    echo "save dir is $SAVEDIR"
    install-game
    register-game-version
    if $INSTALL_WEBSERVER; then
        echo "Installing webserver"
        install-webserver
    fi
else
    echo "Could not figure out version tags. Installation cancelled."
    echo "Aborting installation!"
    echo
    exit 1
fi
