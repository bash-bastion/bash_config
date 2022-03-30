# shellcheck shell=bash

# Original file MIT license (copyright dzove855). Modifications under BSD-3-Clause (copyright me)

main.bash_config() {
	sudo kill "$(fuser 8080/tcp |& awk '{print $2}')" || :

	: "${HTTP_PORT:=8080}"
	: "${BIND_ADDRESS:=127.0.0.1}"
	: "${TMPDIR:=/tmp}"; TMPDIR=${TMPDIR%/}
	: "${LOGFORMAT:="[%t] - %a %m %U %s %b %T"}"
	: "${LOGFILE:=access.log}"
	: "${LOGGING:=1}"

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
	local arg="$BASALT_PACKAGE_DIR/pkg/src/example.sh"
	if [ -z "$arg" ]; then
		print.die "Must profide file to source as first argument"
	fi
	source "$arg"
	if ! declare -f runner &>/dev/null; then
			print.die 'The source file need a function nammed runner which will be executed on each request'
	fi
	run='runner'

	# Listen
	while :; do
		print.info "Listening on address '$BIND_ADDRESS' on port '$HTTP_PORT'"

		# Create temporary directory for each request
		server_tmp_dir=$(mktemp -d)
		: > "$server_tmp_dir/spawnNewProcess"
		(
			# XXX: Accept puts the connection in a TIME_WAIT status.. :(
			# Verifiy if bind_address is specified default to 127.0.0.1
			# You should use the custom accept in order to use bind address and multiple connections
			if ! accept -b "$BIND_ADDRESS" "${HTTP_PORT}"; then
				print.die "Could not listen on ${BIND_ADDRESS}:${HTTP_PORT}"
			fi
			print.info "Spawning (ACCEPT_FD: $ACCEPT_FD)"

			printf '%s' '1' > "$server_tmp_dir/spawnNewProcess"
			printf -v 'TIME_FORMATTED' '%(%d/%b/%Y:%H:%M:%S)T' '-1'
			printf -v 'TIME_SECONDS' '%(%s)T' '-1'
			{
				# We will alway reset all variables and build them again
				local REQUEST_METHOD= REQUEST_PATH= HTTP_VERSION= QUERY_STRING=
				local -A HTTP_HEADERS=()
				local -A POST=()
				local -A GET=()
				local -A HTTP_RESPONSE_HEADERS=()
				local -A COOKIE=()

				# Ensure mktemp will create files inside this temp dir
				local -r TMPDIR="$server_tmp_dir"

				parseHttpRequest
				parseHttpHeaders
				parseGetData
				parseCookieData

				# Parse post data only if length is (a number and) > 0 and post is specified
				if [ "$REQUEST_METHOD" = 'POST' ] && (( ${HTTP_HEADERS['Content-Length']} > 0 )); then
					parsePostData
				fi

				buildResponse
			} <&${ACCEPT_FD} >&${ACCEPT_FD}

			# XXX: This is needed to close the connection to the client
			# XXX: Currently no other way found around it.. :(
			exec {ACCEPT_FD}>&-

			closeee() {
				exec {ACCEPT_FD}>&-
			}
			trap closeee SIGINT

			rm -rf "$server_tmp_dir"
		) &

		until [[ -s "$server_tmp_dir/spawnNewProcess" || ! -f "$server_tmp_dir/spawnNewProcess" ]]; do :; done
	done
}


# https://github.com/dylanaraps/pure-bash-bible#decode-a-percent-encoded-string
urldecode() {
	: "${1//+/ }"
	printf '%b\n' "${_//%/\\x}"
}

parseHttpRequest(){
	# Get information about the request
	read -r REQUEST_METHOD REQUEST_PATH HTTP_VERSION
	HTTP_VERSION="${HTTP_VERSION%%$'\r'}"
}

parseHttpHeaders(){
	local line=
	# Split headers and put it inside HTTP_HEADERS, so it can be reused
	while read -r line; do
		line="${line%%$'\r'}"

		[[ -z "$line" ]] && return
		HTTP_HEADERS["${line%%:*}"]="${line#*:}"
	done
}

parseGetData(){
	local entry
	# Split QUERY_STRING into an assoc, so it can be easy reused
	IFS='?' read -r REQUEST_PATH get <<<"$REQUEST_PATH"

	# Url decode get data
	get="$(urldecode "$get")"

	# Split html #
	IFS='#' read -r REQUEST_PATH _ <<<"$REQUEST_PATH"
	QUERY_STRING="$get"
	IFS='&' read -ra data <<<"$get"
	for entry in "${data[@]}"; do
		GET["${entry%%=*}"]="${entry#*:}"
	done
}

parsePostData(){
	local entry
	# Split POst data into an assoc if is a form, if not create a key raw
	if [[ "${HTTP_HEADERS["Content-type"]}" == "application/x-www-form-urlencoded" ]]; then
		IFS='&' read -rN "${HTTP_HEADERS["Content-Length"]}" -a data
		for entry in "${data[@]}"; do
			entry="${entry%%$'\r'}"
			POST["${entry%%=*}"]="${entry#*:}"
		done
	else
		read -rN "${HTTP_HEADERS["Content-Length"]}" data
		POST["raw"]="${data%%$'\r'}"
	fi
}

parseCookieData(){
	local -a cookie
	local entry key value
	IFS=';' read -ra cookie <<<"${HTTP_HEADERS["Cookie"]}"

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

	HTTP_RESPONSE_HEADERS['status']="${status_code[${1:-200}]}"
}

buildHttpHeaders() {
	# We will first send the status header and then all the other headers
	printf '%s %s\n' "$HTTP_VERSION" "${HTTP_RESPONSE_HEADERS['status']}"
	unset HTTP_RESPONSE_HEADERS['status']

	for key in "${!HTTP_RESPONSE_HEADERS[@]}"; do
		printf '%s: %s\n' "$key" "${HTTP_RESPONSE_HEADERS[$key]}"
	done
}

buildResponse() {
	# Every output will first be saved in a file and then printed to the output
	# Like this we can build a clean output to the client

	# Build defualt header
	httpSendStatus 200

	# Get mime type
	IFS='.' read -r _ extension <<<"$REQUEST_PATH"
	if [[ -n "${MIME_TYPES["${extension:-html}"]}" ]]; then
		HTTP_RESPONSE_HEADERS["Content-Type"]="${MIME_TYPES["${extension:-html}"]}"
	fi

	"$run" > "$TMPDIR/output"

	# Get content-length
	if PATH='' type -p 'finfo' &>/dev/null; then
		HTTP_RESPONSE_HEADERS["Content-Length"]=$(finfo -s "$TMPDIR/output")
	fi

	if (( LOGGING )); then
		logPrint
	fi

	buildHttpHeaders
	printf "\n" # HTTP RFC 2616 send newline before body
	cat "$TMPDIR/output"
}

logPrint(){
	local -A logformat
	local output="${LOGFORMAT}"

	logformat["%a"]=$RHOST
	logformat["%A"]=$BIND_ADDRESS
	logformat["%b"]=${HTTP_RESPONSE_HEADERS["Content-Length"]}
	logformat["%m"]=$REQUEST_METHOD
	logformat["%q"]=$QUERY_STRING
	logformat["%t"]=$TIME_FORMATTED
	logformat["%s"]=${HTTP_RESPONSE_HEADERS['status']%% *}
	logformat["%T"]=$(( $(printf '%(%s)T' -1 ) - TIME_SECONDS))
	logformat["%U"]=$REQUEST_PATH

	local key=
	for key in "${!logformat[@]}"; do
		output="${output//"$key"/"${logformat[$key]}"}"
	done; unset -v key

	cat <<< "$output" >> "$LOGFILE"
}

