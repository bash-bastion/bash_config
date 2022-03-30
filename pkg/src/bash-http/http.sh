# shellcheck shell=bash

http.serve() {
	local file="$BASALT_PACKAGE_DIR/pkg/share/templates/$1"
	if [ -f "$file" ]; then
		cat "$file"
	else
		print.die "Failed to find file at '$file'"
	fi
}
