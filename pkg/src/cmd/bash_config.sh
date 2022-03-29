# shellcheck shell=bash

main.bash_config() {
	local port="${PORT:-3000}"

	socat TCP4-LISTEN:"$port",reuseaddr,fork,end-close EXEC:"$BASALT_PACKAGE_DIR/pkg/libexec/server.sh"
}
