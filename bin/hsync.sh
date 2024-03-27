#! /bin/bash
set -e

STAGING_DIR=/tmp/iuksync/$RANDOM
matchpicked_files=()
DEFAULT_SOURCE_DIR="$HOME/.local/share/hsync/source"

APP_NAME=$(basename "$0")
ABOUT="Syncronize the home directory across workstations."
CLI=(
    --prefix "args_"
    -O "source;Source directory;$DEFAULT_SOURCE_DIR;s"
    -O "hostname;Use a custom hostname;$(hostnamectl hostname)"
    -f "review;Review all changes before applying;;r"
    -f "dry-run;Make all preparations but don't apply (implies --review);;D"
)
CLI=$(spongecrab --name "$APP_NAME" --about "$ABOUT" "${CLI[@]}" -- "$@") || exit 1
eval "$CLI" || exit 1

[[ -z $args_dry_run ]] || args_review=1
SOURCE_DIR=`realpath $args_source`
HOSTNAME=$args_hostname

check_suspicious() {
    if [[ -z $(ls -a "$args_source" | grep -E "(.config|.local)") ]]; then
        printcolor -ns warn "Suspicious directory:"
        echo " $SOURCE_DIR"
        lsl "$SOURCE_DIR"
        promptconfirm -d "This folder does not look like a home directory. Continue?" -- -s warn || exit_error "User cancelled the operation."
    fi
}

cleanup_staging() {
    printcolor -ns ok "Cleaning up:"
    echo " $STAGING_DIR"
    rm -rf $STAGING_DIR
}

prepare_staging() {
    rm -rf $STAGING_DIR
    mkdir --parents $STAGING_DIR
    printcolor -ns ok "Temporary directory:"
    echo " $STAGING_DIR"
    printcolor -ns ok "Source directory:"
    echo " $SOURCE_DIR"
    cd $SOURCE_DIR
    printcolor -s ok "Preparing staging..."
    cp -rf --parents . $STAGING_DIR
    local mp_pattern=$(matchpick --print-start)
    local mp_files=$(grep --files-with-match --recursive $mp_pattern $STAGING_DIR)
    for file in $mp_files; do
        printcolor -ns debug "Matchpicking:"
        echo " `realpath --relative-to=$STAGING_DIR $file`"
        matchpick $file -o $file -m $HOSTNAME
        matchpicked_files+=("$file")
    done
}

review_staging() {
    promptconfirm "Review matchpicked files?" && bat ${matchpicked_files[@]}
    promptconfirm "List all files?" && lsr --nopaging $STAGING_DIR
    [[ -n $args_dry_run ]] || promptconfirm "yellow]Continue?"
}

apply_staging() {
    cd $STAGING_DIR
    printcolor -ns ok "Applying..."
    echo " $HOME"
    cp -rf --parents . $HOME
}

[[ -d $SOURCE_DIR ]] || exit_error "Invalid source directory: $args_source"

check_suspicious
prepare_staging
[[ -z $args_review ]] || review_staging
[[ -n $args_dry_run ]] || apply_staging
cleanup_staging
