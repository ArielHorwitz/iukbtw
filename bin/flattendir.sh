#!/bin/bash

APP_NAME=$(basename "$0")
ABOUT="Recursively copy files from directory to a flat directory."
CLI=(
    -p "nested"
    -p "target"
    -f "force;;;f"
    -f "verbose;;;v"
)
CLI=$(spongecrab --name "$APP_NAME" --about "$ABOUT" "${CLI[@]}" -- "$@") || exit 1
eval "$CLI" || exit 1

# Verify arguments and prepare target dir
[[ -d $nested ]] || exit_error "'$nested' is not a directory"
[[ -d $target ]] && [[ -z $force ]] && exit_error "'$target' already exists (override using --force)"
[[ -d $target ]] && rm -rf $target || true
[[ -n $verbose ]] && verbose="--verbose" || true
mkdir $target

# Flatten
[[ -n $verbose ]] && printcolor -s debug "Flattening: '$nested' => '$target'" || true
find $nested -type f -exec cp $verbose --backup=numbered -t $target '{}' +
[[ -n $verbose ]] && printcolor -s ok "Flattened." || true
