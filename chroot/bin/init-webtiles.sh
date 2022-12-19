#! /bin/sh

NAME=$1

VERSIONS="git $(seq 29 29 | sed 's/^/0./')"

for v in $VERSIONS; do
    cp --no-clobber "%%DGLDIR%%/data/crawl-$v-settings/init.txt" "%%RCFILESDIR%%/crawl-$v/$NAME.rc"
    cp --no-clobber "%%DGLDIR%%/data/crawl-git.macro" "%%RCFILESDIR%%/crawl-$v/$NAME.macro"
done

mkdir -p "%%MORGUEDIR%%/$NAME"
mkdir -p "%%TTYRECDIR%%/$NAME"
