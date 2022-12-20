#! /bin/sh

NAME=$1

VERSIONS="git"

for v in $VERSIONS; do
    cp --no-clobber "%%DGL_CHROOT%%/crawl-$v.rc" "%%RCFILESDIR%%/crawl-$v/$NAME.rc"
    cp --no-clobber "%%DGL_CHROOT%%/crawl-git.macro" "%%RCFILESDIR%%/crawl-$v/$NAME.macro"
done

mkdir -p "%%MORGUEDIR%%/$NAME"
mkdir -p "%%TTYRECDIR%%/$NAME"
