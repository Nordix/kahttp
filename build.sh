#! /bin/sh
##
## build.sh --
##   Build kahttp.
##
## Commands;
##

prg=$(basename $0)
if uname | grep -q Darwin ; then
	test -s "$dir" && dir=$(stat -f%Y "$0")
else
	dir=$(readlink -f "$dir")
fi
tmp=/tmp/${prg}_$$

die() {
    echo "ERROR: $*" >&2
    rm -rf $tmp
    exit 1
}
help() {
    grep '^##' $0 | cut -c3-
    rm -rf $tmp
    exit 0
}
test -n "$1" || help
echo "$1" | grep -qi "^help\|-h" && help

log() {
	echo "$prg: $*" >&2
}
dbg() {
	test -n "$__verbose" && echo "$prg: $*" >&2
}

##  env
##    Print environment.
##
cmd_env() {
	test -n "$__image" || __image=registry.nordix.org/cloud-native/kahttp
	test -n "$__version" || __version=latest
	test -n "$__localpath" || __localpath=build/kahttp
	test "$cmd" = "env" && set | grep -E '^(__.*)='
}

##  image [--image=registry.nordix.org/cloud-native/kahttp] [--version=latest]
##    Build the "kahttp" image.
##
cmd_image() {
	cmd_env
	mkdir -p image
	GO111MODULE=on CGO_ENABLED=0 GOOS=linux \
		go build -ldflags "-extldflags '-static' -X main.version=$__version" \
		-o image/kahttp ./cmd/... || die "Build failed"
	uname | grep -q Darwin || strip image/kahttp
	docker build -t $__image:$__version .
}

##  local [--localpath=build/kahttp]
##    Build the "kahttp" binary for local usage.
##
cmd_local() {
	cmd_env
	mkdir -p build
	go build -o $__localpath/kahttp ./cmd/... || die "Build failed"
}


# Get the command
cmd=$1
shift
grep -q "^cmd_$cmd()" $0 $hook || die "Invalid command [$cmd]"

while echo "$1" | grep -q '^--'; do
    if echo $1 | grep -q =; then
	o=$(echo "$1" | cut -d= -f1 | sed -e 's,-,_,g')
	v=$(echo "$1" | cut -d= -f2-)
	eval "$o=\"$v\""
    else
	o=$(echo "$1" | sed -e 's,-,_,g')
	eval "$o=yes"
    fi
    shift
done
unset o v
long_opts=`set | grep '^__' | cut -d= -f1`

# Execute command
trap "die Interrupted" INT TERM
cmd_$cmd "$@"
status=$?
rm -rf $tmp
exit $status
