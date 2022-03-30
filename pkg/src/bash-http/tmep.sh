# shellcheck shell=bash

serveHtml() {
	[[ $DOCUMENT_ROOT == *('..'|'~')* ]]
}
