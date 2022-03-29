# shellcheck shell=bash

util.trim() {
	unset REPLY; REPLY=
	local REPLY="$1"

	REPLY="${REPLY#"${REPLY%%[![:space:]]*}"}"
	REPLY="${REPLY%"${REPLY##*[![:space:]]}"}"
}

util.log_debug() {
	printf '%s\n' "$1" >&4
}

util.ensure_nonzero() {
	local name="$1"

	if [ -z "$name" ]; then
		bprint.fatal "Argument 'name' for function 'ensure.nonzero' is empty"
	fi

	local -n value="$name"
	if [ -z "$value" ]; then
		bprint.fatal "Argument '$name' for function '${FUNCNAME[1]}' is empty"
	fi
}

util.ensure_cd() {
	local dir="$1"

	ensure.nonzero 'dir'

	if ! cd "$dir"; then
		bprint.fatal "Could not cd to directory '$dir'"
	fi
}
