# shellcheck shell=bash

runner() {
	case $REQ_URL in
	/)
		http.template 'root.html'
		;;
	/dircolors)
		http.template 'dircolors.html'
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
		shopt -o
		printf '%s\n' '<h2>shopt</h2>'
		shopt
		http.serve 'foot.html'
		;;
	/aliases)
		http.template 'aliases.html'
		;;
	/functions)
		http.template 'functions.html'
		;;
	/history)
		HISTFILE="$XDG_STATE_HOME/history/bash_history" # TODO
		local file="${HISTFILE:-"$HOME/.bash_history"}"

		while IFS= read -r timestamp && read -r cmd; do
			timestamp=${timestamp#\#}
			printf '%s\n' "<p>$timestamp: ${cmd}</p>"
		done < "$file"
		;;
	/bindings)
		http.template 'bindings.html'
		;;
	/public/*)
		http.public "${REQ_URL#/public/}"
		;;
	*)
		http.template '404.html'
		;;
	esac
	http.serve 'foot.html'
}
