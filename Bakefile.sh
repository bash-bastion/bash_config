# shellcheck shell=bash

task.build() {
	cd ./pkg/builtins
	gcc -shared -fpic -I /usr/include/bash -I /usr/include/bash/builtins -I /usr/include/bash/include -I /usr/lib/bash -o './accept' './accept.c'
}
