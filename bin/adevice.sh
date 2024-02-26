#! /bin/bash
set -e

HARDWARE_DIR=$HOME/.config/hardware/audio
SPEAKERS_FILE=$HARDWARE_DIR/speakers
HEADPHONES_FILE=$HARDWARE_DIR/speakers
ALL_DEVICES=`pactl list short`

APP_NAME=$(basename "$0")
ABOUT="Get and set default audio device."
CLI=(
    --prefix "args_"
    -o "class;Device class"
    -f "mic;Use source instead of sink;;m"
    -f "list;List devices or classes;;l"
    -f "path;List device directory path;;p"
    -f "quiet;Be quiet (overrides --verbose);;q"
    -f "verbose;Display more info;;v"
)
CLI=$(spongecrab --name "$APP_NAME" --about "$ABOUT" "${CLI[@]}" -- "$@") || exit 1
eval "$CLI" || exit 1

QUIET=
VERBOSE=
if [[ -n $args_quiet ]]; then
    QUIET=1
elif [[ -n $args_verbose ]]; then
    VERBOSE=1
fi

device_class=$args_class
if [[ -n $args_mic ]]; then
    device_type="source"
else
    device_type="sink"
fi
name_default=@DEFAULT_${device_type^^}@

list_devices() {
    ls -1 $HARDWARE_DIR
}

find_device() {
    local class=$1
    local file=$HARDWARE_DIR/$class
    local device
    local device_exists
    for device in `decomment $file`; do
        if [[ -n $VERBOSE ]]; then
            tcprint "debug n]Looking for device:" >&2
            echo " $device" >&2
        fi
        device_exists=$(printf "$ALL_DEVICES" | grep -m 1 $device || echo '')
        if [[ -n $device_exists ]]; then
            echo $device
            return 0
        fi
    done
    return 1
}

get_device() {
    pactl get-default-${device_type}
}

set_device() {
    local device=$1
    pactl set-default-${device_type} $device
}

# Quick operations
if [[ -n $args_path ]]; then
    echo $HARDWARE_DIR
    exit 0
elif [[ -n $args_list ]]; then
    if [[ -n $device_class ]]; then
        bat -pp $HARDWARE_DIR/$device_class
        echo
    else
        list_devices
    fi
    exit 0
fi
if [[ -z $device_class ]]; then
    get_device
    exit 0
fi

# Set default device
selected_device=$(find_device $device_class) || exit_error "No device found"
if [[ -z $QUIET ]]; then
    tcprint "info n]Selected device:" >&2
    echo " $selected_device" >&2
fi
set_device $selected_device
