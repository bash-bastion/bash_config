#!/usr/bin/env bash

eval "$(basalt-package-init)" || exit
basalt.package-init || exit
basalt.package-load

source "$BASALT_PACKAGE_DIR/pkg/src/bin/bash_config.sh"
main.bash_config "$@"
