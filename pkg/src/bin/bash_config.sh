# shellcheck shell=bash

# Original file MIT license (copyright dzove855). Modifications under BSD-3-Clause (copyright me)

main.bash_config() {
	: "${PORT:=8080}"
	: "${BIND_ADDRESS:=127.0.0.1}"
	: "${TMPDIR:=/tmp}"; TMPDIR=${TMPDIR%/}
	: "${LOGFORMAT:="[%t] - %a %m %U %s %b %T"}"
	: "${LOGFILE:=access.log}"
	: "${LOGGING:=1}"
	HTTP_PORT=$PORT

	# Setup mime types
	local -A MIME_TYPES=()
	local types= extension=
	while IFS= read -r types extension; do
		read -ra extensions <<< "$extension"
		local ext=
		for ext in "${extensions[@]}"; do
			MIME_TYPES["$ext"]="$types"
		done; unset -v ext
	done < "$BASALT_PACKAGE_DIR/pkg/share/mime-types.txt"; unset -v types extension

	# Use accept builtin
	BASH_LOADABLE_PATH="$BASALT_PACKAGE_DIR/pkg/builtins"
	if [[ ! -f "$BASH_LOADABLE_PATH/accept" ]]; then
		print.die "Accept not found"
	fi
	if ! enable -f "$BASH_LOADABLE_PATH/accept" accept; then
		print.die "Could not load accept"
	fi

	# Source the runner
	local arg="$BASALT_PACKAGE_DIR/pkg/src/server.sh"
	if [ -z "$arg" ]; then
		print.die "Must profide file to source as first argument"
	fi
	source "$arg"
	if ! declare -f server &>/dev/null; then
			print.die 'The source file need a function nammed runner which will be executed on each request'
	fi
	run='server'

	int_handler() {
		local job=
		for job in $(jobs -p); do
			kill -9 "$job"
		done
		exit 1
	}
	trap 'int_handler' INT

	# Listen
	while :; do
		print.info "Listening on address '$BIND_ADDRESS' on port '$HTTP_PORT'"

		# Create temporary directory for each request
		server_tmp_dir=$(mktemp -d)
		: > "$server_tmp_dir/spawn-new-process"
		(
			# XXX: Accept puts the connection in a TIME_WAIT status.. :(
			# Verifiy if bind_address is specified default to 127.0.0.1
			# You should use the custom accept in order to use bind address and multiple connections

			if ! accept -b "$BIND_ADDRESS" "$HTTP_PORT"; then
				print.die "Could not listen on ${BIND_ADDRESS}:${HTTP_PORT}"
			fi
			print.info "Spawning (ACCEPT_FD: $ACCEPT_FD)"

			printf '%s' '1' > "$server_tmp_dir/spawn-new-process"
			printf -v TIME_FORMATTED '%(%d/%b/%Y:%H:%M:%S)T' '-1'
			printf -v TIME_SECONDS '%(%s)T' '-1'
			{
				# We will alway reset all variables and build them again
				local HTTP_VERSION=
				local REQ_METHOD= REQ_URL= REQ_QUERY=
				local -A REQ_HEADERS=()
				local -A GET=()
				local -A POST=()
				local -A RES_HEADERS=()
				local -A COOKIE=()

				# Ensure mktemp will create files inside this temp dir
				local -r TMPDIR="$server_tmp_dir"

				parseHttpRequest
				parseHttpHeaders
				parseGetData
				parseCookieData

				# Parse post data only if length is (a number and) > 0 and post is specified
				if [ "$REQ_METHOD" = 'POST' ] && (( ${REQ_HEADERS['Content-Length']} > 0 )); then
					parsePostData
				fi

				# SEND RESPONSE
				# Every output will first be saved in a file and then printed to the output
				# Like this we can build a clean output to the client

				# Build defualt header
				httpSendStatus 200

				# Get mime type
				IFS='.' read -r _ extension <<< "$REQ_URL"
				: "${extension:=html}"
				if [ -n "${MIME_TYPES[$extension]}" ]; then
					RES_HEADERS["Content-Type"]="${MIME_TYPES[$extension]}"
				fi

				"$run" > "$TMPDIR/output"

				# Get content-length
				if PATH= type -p 'finfo' &>/dev/null; then
					RES_HEADERS["Content-Length"]=$(finfo -s "$TMPDIR/output")
				fi

				if (( LOGGING )); then
					print.log
				fi

				buildHttpHeaders
				printf '\n' # HTTP RFC 2616 send newline before body
				printf '%s\n' "$(<"$TMPDIR/output")"
				# cat "$TMPDIR/output"
			} <& "${ACCEPT_FD}" >& "${ACCEPT_FD}"

			# XXX: This is needed to close the connection to the client
			# XXX: Currently no other way found around it.. :(
			exec {ACCEPT_FD}>&-

			rm -rf "$server_tmp_dir"
		) &

		until [[ -s "$server_tmp_dir/spawn-new-process" || ! -f "$server_tmp_dir/spawn-new-process" ]]; do :; done
	done
}


# https://github.com/dylanaraps/pure-bash-bible#decode-a-percent-encoded-string
urldecode() {
	: "${1//+/ }"
	printf '%b\n' "${_//%/\\x}"
}

parseHttpRequest(){
	# Get information about the request
	read -r REQ_METHOD REQ_URL HTTP_VERSION
	HTTP_VERSION="${HTTP_VERSION%%$'\r'}"
}

parseHttpHeaders(){
	local line=
	# Split headers and put it inside REQ_HEADERS, so it can be reused
	while read -r line; do
		line="${line%%$'\r'}"

		[[ -z "$line" ]] && return
		REQ_HEADERS["${line%%:*}"]="${line#*:}"
	done
}

parseGetData(){
	local entry
	# Split REQ_QUERY into an assoc, so it can be easy reused
	IFS='?' read -r REQ_URL get <<<"$REQ_URL"

	# Url decode get data
	get="$(urldecode "$get")"

	# Split html #
	IFS='#' read -r REQ_URL _ <<<"$REQ_URL"
	REQ_QUERY="$get"
	IFS='&' read -ra data <<<"$get"
	for entry in "${data[@]}"; do
		GET["${entry%%=*}"]="${entry#*:}"
	done
}

parsePostData(){
	local entry=
	# Split Post data into an assoc if is a form, if not create a key raw
	if [[ "${REQ_HEADERS["Content-type"]}" == "application/x-www-form-urlencoded" ]]; then
		IFS='&' read -rN "${REQ_HEADERS["Content-Length"]}" -a data
		for entry in "${data[@]}"; do
			entry="${entry%%$'\r'}"
			POST["${entry%%=*}"]="${entry#*:}"
		done
	else
		read -rN "${REQ_HEADERS["Content-Length"]}" data
		POST["raw"]="${data%%$'\r'}"
	fi
}

parseCookieData(){
	local -a cookie
	local entry= key= value=
	IFS=';' read -ra cookie <<<"${REQ_HEADERS["Cookie"]}"

	for entry in "${cookie[@]}"; do
		IFS='=' read -r key value <<<"$entry"
		COOKIE["${key# }"]="${value% }"
	done
}

httpSendStatus() {
	local -A status_code=(
		[200]="200 OK"
		[201]="201 Created"
		[301]="301 Moved Permanently"
		[302]="302 Found"
		[400]="400 Bad Request"
		[401]="401 Unauthorized"
		[403]="403 Forbidden"
		[404]="404 Not Found"
		[405]="405 Method Not Allowed"
		[500]="500 Internal Server Error"
	)

	RES_HEADERS['status']="${status_code[${1:-200}]}"
}

buildHttpHeaders() {
	# We will first send the status header and then all the other headers
	printf '%s %s\n' "$HTTP_VERSION" "${RES_HEADERS['status']}"
	unset RES_HEADERS['status']

	for key in "${!RES_HEADERS[@]}"; do
		printf '%s: %s\n' "$key" "${RES_HEADERS[$key]}"
	done
}
