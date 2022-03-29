#!/usr/bin/env bash

eval "$(basalt-package-init)"
basalt.package-init
basalt.package-load

# util.add_status_line() {
# 	local variable_name="$1"
# 	local status_code="$2"
# 	local status_message="$3"

# 	local -n __variable="$variable_name"
# 	__variable+="HTTP/1.1 ${status_code} ${status_message}"$'\r\n'
# }

# util.add_header() {
# 	local variable_name="$1"
# 	local header_name="$2"
# 	local header_content="$3"

# 	local -n __variable="$variable_name"
# 	__variable+="${header_name}: ${header_content}"$'\r\n'
# }

# util.add_body() {
# 	local variable_name="$1"
# 	local body="$2"

# 	local -n __variable="$variable_name"
# 	__variable+=$'\r\n'"${body}"$'\r\n'
# }

# main.bash_configui() {
# 	local data="HTTP/1.1 200 OK"$'\r\n'"Connection: keep-alive"$'\r\n'"Content-Length: 4"$'\r\n\r\n'"UwU!"$'\r\n'

error_handler() {
	local exit_code=$?

	# TODO: print stack trace in html
	bhttp.res_template 'unhandled-error'

	exit $exit_code
}
trap 'error_handler' ERR

main() {
	exec 4>&2

	bhttp.init
	local req_method="$REPLY1"
	local req_url="$REPLY2"

	case "$req_url" in
	/) bhttp.send_template 'root.html' ;;
	/a) bhttp.send_template 'a.html' ;;
	/b) bhttp.send_template 'b.html' ;;
	/public/pure.css) bhttp.send_file 'css/pure-min.css' ;;
	*) bhttp.send_template '404.html' ;;
	esac
}

main "$@"
