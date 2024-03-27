#! /bin/bash
set -e

MOUNTPOINT_DIR="/mnt"
LSBLK_ARGS="--noheadings"
LSBLK_COLS="NAME,MOUNTPOINT,LABEL,SIZE,FSUSE%"
LSBLK_COLS_FULL="NAME,VENDOR,MOUNTPOINT,LABEL,FSTYPE,PARTTYPENAME,FSVER,SIZE,FSSIZE,FSUSED,FSUSE%,FSAVAIL,MODEL"

APP_NAME=$(basename "$0")
ABOUT="List, mount, and unmount volumes.

Volumes can be specified by label or path basename (e.g. sda1, sdc2)."
CLI=(
    --prefix "args_"
    -o "volume;Volume label or name;;m"
    -f "mount;Mount;;m"
    -f "unmount;Unmount;;u"
    -f "mountpoint;Print mountpoint;;M"
    -f "path;Print path;;P"
    -f "label;Print label (lowercase);;L"
    -f "force;Don't ask for confirmation;;f"
    -f "verbose;Print more data;;v"
)
CLI=$(spongecrab --name "$APP_NAME" --about "$ABOUT" "${CLI[@]}" -- "$@") || exit 1
# printf "$CLI\n"
eval "$CLI" || exit 1

print_disks() {
    set -e
    if [[ -n $args_verbose ]]; then
        local args=
        local cols=$LSBLK_COLS_FULL
    else
        local args="--noheadings"
        local cols=$LSBLK_COLS
    fi
    lsblk $args --output $cols
}

path_to_label() {
    set -e
    local label=$(lsblk --noheadings --output LABEL "$1" | head -n1)
    [[ $(get_path "$label") = $1 ]] && echo $label | tr '[:upper:]' '[:lower:]'
}

mount_path_exists() {
    [[ -n $(lsblk --noheadings --output PATH | grep $1) ]]
}

get_path() {
    set -e
    # get from path basename
    mount_path_exists "/dev/$1" && echo "/dev/$1" && return 0
    # get from label
    local path=$(lsblk -nlo PATH,LABEL | grep -i "$1" | awk '{print $1}')
    mount_path_exists $path && echo $path && return 0

    return 1
}

[[ -n $args_volume ]] || { print_disks && exit 0; }

path=$(get_path "$args_volume") || exit_error "Unknown name or label: $args_volume"

[[ -z "$args_path" ]] || { echo $path && exit 0; }

label=$(path_to_label $path) || exit_error "Missing label: $path"

[[ -z "$args_label" ]] || { echo $label && exit 0; }

mountpoint=${MOUNTPOINT_DIR}/${label}

[[ -z "$args_mountpoint" ]] || { echo $mountpoint && exit 0; }

if [[ -n "$args_unmount" ]]; then

    printcolor -s notice "Syncing and unmounting $path <- $mountpoint" >&2
    [[ -n $args_force ]] || promptconfirm "Proceed?" || exit_error "User aborted"

    sync || exit_error "Failed to sync"
    sudo umount "$path" || exit_error "Failed to unmount"
    echo $path $mountpoint

elif [[ -n "$args_mount" ]]; then

    printcolor -s notice "Mounting: $path -> $mountpoint" >&2
    [[ ! -e $mountpoint ]] || printcolor -s warn "Mount point exists" >&2
    [[ -n $args_force ]] || promptconfirm "Proceed?" || exit_error "User aborted"

    [[ -d $mountpoint ]] || sudo mkdir --parents $mountpoint
    sudo mount "$path" "$mountpoint" || exit_error "Failed to mount"
    echo $path $mountpoint

else
    exit_error "Missing operation"
fi
