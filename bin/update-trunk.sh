#!/bin/bash

cd "$DGL_CONF_HOME/crawl-build"

# shellcheck source=crawl-build/update-crawl-stable-build.sh
source ./build-and-install-crawl.sh -lw $@
