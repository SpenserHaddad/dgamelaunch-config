#! /bin/sh

set -e

NAME=$1

VERSIONS="%%CRAWL_VERSIONS%%"

for v in $VERSIONS; do
    cp --no-clobber "%%DGLDIR%%/crawl-$v.rc" "%%RCFILESDIR%%/crawl-$v/$NAME.rc"
    cp --no-clobber "%%DGLDIR%%/crawl-git.macro" "%%RCFILESDIR%%/crawl-$v/$NAME.macro"
done

mkdir -p "%%MORGUEDIR%%/$NAME"
mkdir -p "%%TTYRECDIR%%/$NAME"
