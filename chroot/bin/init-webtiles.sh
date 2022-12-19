#! /bin/sh

NAME=$1

VERSIONS="git $(seq 29 29 | sed 's/^/0./')"

for v in $VERSIONS; do
    cp --no-clobber "%%DGL_CHROOT%%/%%CHROOT_DGLDIR%%/data/crawl-$v-settings/init.txt" "%%CHROOT_RCFILESDIR%%/crawl-$v/$NAME.rc"
    cp --no-clobber "%%DGL_CHROOT%%/%%CHROOT_DGLDIR%%/data/crawl-git.macro" "%%CHROOT_RCFILESDIR%%/crawl-$v/$NAME.macro"
done

mkdir -p "%%DGL_CHROOT%%/%%CHROOT_MORGUEDIR%%/$NAME"
mkdir -p "%%DGL_CHROOT%%/%%CHROOT_TTYRECDIR%%/$NAME"
