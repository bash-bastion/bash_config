# shellcheck shell=bash

http.serve() {
	local file1="$BASALT_PACKAGE_DIR/pkg/share/templates/$1"
	local file2="$BASALT_PACKAGE_DIR/pkg/share/partials/$1"
	local file3="$BASALT_PACKAGE_DIR/pkg/share/$1"

	if [ -f "$file1" ]; then
		cat "$file1"
	elif [ -f "$file2" ]; then
		cat "$file2"
	elif [ -f "$file3" ]; then
		cat "$file3"
	else
		print.die "Failed to find file '$1'"
	fi
}

http.template() {
	http.serve 'head.html'
	http.serve "$1"
	http.serve 'foot.html'
}


http.public() {
	local file="$1"
	local path="$BASALT_PACKAGE_DIR/pkg/share/public/$file"
	if [ -f "$path" ]; then
		cat "$path"
	else
		print.die "Failed to find file '$file' in the public dir"
	fi
}
