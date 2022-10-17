# shellcheck shell=bash

server() {
	case $REQ_URL in
	/public/*)
		http.public "${REQ_URL#/public/}"
		;;
	/)
		http.template 'root.html'
		;;
	/dircolors)
		http.template 'dircolors.html'
		dircolors
		;;
	/prompt)
		http.template 'prompt.html'
		;;
	/variables)
		http.template 'variables.html'
		;;
	/options)
		http.serve 'head.html'
		http.serve 'options.html'
		printf '%s\n' '<h2>set</h2>'
		while read -r name value; do
			printf '%s\n' "<div><input type=\"checkbox\"></input><span>$name</span></div>"
		done < <(set -o)

		printf '%s\n' '<h2>shopt</h2>'
		while read -r name value; do
			printf '%s\n' "<div><input type=\"checkbox\"></input><span>$name</span></div>"
		done < <(shopt)
		http.serve 'foot.html'
		;;
	/aliases)
		# http.template 'aliases.html'
		http.serve 'head.html'
		alias -p
		http.serve 'foot.html'
		;;
	/functions)
		http.template 'functions.html'
		;;
	/history)
		http.serve 'head.html'
		HISTFILE="$XDG_STATE_HOME/history/bash_history" # TODO
		local file="${HISTFILE:-"$HOME/.bash_history"}"

		while IFS= read -r timestamp && read -r cmd; do
			timestamp=${timestamp#\#}
			printf '%s\n' "<p>$timestamp: ${cmd}</p>"
		done < "$file"
		http.serve 'foot.html'
		;;
	/bindings)
		http.serve 'head.html'
		# http.template 'bindings.html'
		bind -v
		http.serve 'foot.html'
		;;
	*)
		http.template '404.html'
		;;
	esac
	http.serve 'foot.html'
}
