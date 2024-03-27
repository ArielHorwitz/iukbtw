#! /bin/bash

printcolor -s error "$1" >&2
[[ -z $2 ]] || printcolor -s warn "Please report bugs to: $2" >&2
exit 1

