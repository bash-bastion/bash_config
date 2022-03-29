# shellcheck shell=bash

# Must be called to create variables for the request
bhttp.init() {
	unset REPLY{1,2}; REPLY1=; REPLY2=

	declare -gA global_res_http_headers=(
		[Server]='bash-http'
		[Cache-Control]='Cache-Control: no-store, must-revalidate'
	)
	declare -g global_res_http_status='200'

	local line=
	if ! read -r line; then
		bhttp.res_template 'error'
		return
	fi

	local req_method= req_url= req_http_version=
	read -r req_method req_url req_http_version <<< "$line"

	util.log_debug "req_method: $req_method"
	util.log_debug "req_url: $req_url"
	util.log_debug "req_http_version: $req_http_version"

	local line=
	if read -r line || [ -n "$line" ]; then
		local req_header= req_header_value=
		IFS=':' read -r req_header req_header_value <<< "$line"

		req_header="${req_header#"${req_header%%[![:space:]]*}"}"
		req_header="${req_header%"${req_header##*[![:space:]]}"}"
		req_header_value="${req_header_value#"${req_header_value%%[![:space:]]*}"}"
		req_header_value="${req_header_value%"${req_header_value##*[![:space:]]}"}"

		util.log_debug "header: $req_header|$req_header_value"
	fi

	util.log_debug '---'

	REPLY1="$req_method"
	REPLY2="$req_url"
}

bhttp.set_status() {
	global_res_http_status="$1"
}

bhttp.set_header() {
	global_res_http_headers["$1"]="$2"
}

bhttp.send_headers() {
	declare -rA http_map=(
		[200]='OK'
		[304]='Not Modified'
		[400]='Bad Request'
		[403]='Forbidden'
		[404]='Not Found'
		[405]='Method Not Allowed'
		[500]='Internal Server Error'
	)

	local status_code="$global_res_http_status"
	local status="${http_map[$status_code]}"
	printf '%s' "HTTP/1.1 $status_code $status"$'\r\n'

	local utc_time=
	TZ='UTC' printf -v utc_time '%(%a, %d %b %Y %T %z)T'
	utc_time="${utc_time/%+0000/UTC}"

	bhttp.set_header 'Date' "$utc_time"
	bhttp.set_header 'Expires' "$utc_time"

	local key=
	for key in "${!global_res_http_headers[@]}"; do
		printf '%s' "$key: ${global_res_http_headers[$key]}"$'\r\n' | tee >(cat >&3)
	done; unset key
	printf '\r\n'
}

bhttp.send_template() {
	local file="$1"
	local file_path="$BASALT_PACKAGE_DIR/pkg/share/templates/$file"
	if [ ! -f "$file_path" ]; then
		local html='<!DOCTYPE html>
<html>

<head>
	<meta charset="utf-8">
	<title>Error</title>
	<meta name="description" content="Error">
</head>
<body>
	<h1>Error</h1>
	<h2>Your error here</h2>
</body>
</html>'
		echo "$html"
	fi

	bhttp.set_status 200
	bhttp.set_header 'Content-Type' 'text/html; charset=utf-8'
	bhttp.send_headers

	local html=
	html="$(<"$file_path")"
	echo "$html"

	exit 0
}

bhttp.send_file() {
	local file="$1"
	local file_path="$BASALT_PACKAGE_DIR/pkg/share/$file"
	if [ ! -f "$file_path" ]; then
		local html='<!DOCTYPE html>
<html>

<head>
	<meta charset="utf-8">
	<title>Error</title>
	<meta name="description" content="Error">
</head>
<body>
	<h1>Error</h1>
	<h2>Your error here</h2>
</body>
</html>'
		echo "$html"
	fi

	bhttp.set_status 200
	case "${file##*.}" in
	css)
		bhttp.set_header 'Content-Type' 'text/css; charset=utf-8'
		;;
	*)
		bhttp.set_header 'Content-Type' 'text/html; charset=utf-8'
		;;
	esac
	bhttp.send_headers

	local content=
	content="$(<"$file_path")"
	printf '%s\n' "$content"

	exit 0
}
