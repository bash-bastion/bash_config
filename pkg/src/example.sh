# shellcheck shell=bash

runner(){
	case $REQUEST_PATH in
	'/')
		http.serve 'root.html'
		;;
	'/a')
		http.serve 'a.html'
		;;
	'/b')
		http.serve 'b.html'
		;;
	'/c')
		http.serve 'c.html'
		;;
	*)
		http.serve '404.html'
		;;
	esac
}
