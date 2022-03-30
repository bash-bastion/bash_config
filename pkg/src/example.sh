# shellcheck shell=bash

runner(){
	case $REQUEST_PATH in
	'/a')
		echo 'a'
		;;
	'/b')
		echo 'b'
		;;
	'/c')
		echo 'c'
		;;
	*)
		http.serve '404.html'
		;;
	esac
}
