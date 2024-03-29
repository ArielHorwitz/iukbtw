#! /bin/bash

DISPLAYS_FILE=$HOME/.config/hardware/displays

# Command line interface (based on `spongecrab --generate`)
APP_NAME=$(basename "$0")
ABOUT="Configure displays"
CLI=(
    -c "displays;Displays from left to right"
    -O "file;Read displays from file;;f"
    -O "primary;Set primary display;;p"
    -f "list;List connected outputs and quit;;l"
    -f "list-all;List all outputs and quit;;L"
)
CLI=$(spongecrab --name "$APP_NAME" --about "$ABOUT" "${CLI[@]}" -- "$@") || exit 1
eval "$CLI" || exit 1

[[ -z $list_all ]] || { xrandr -q | grep "connected" | awk '{print $1}' | sort ; exit 0 ; }
[[ -z $list ]] || { xrandr -q | grep " connected" | sort ; exit 0 ; }

xrandr --auto

[[ -n $displays ]] || mapfile -t displays < $DISPLAYS_FILE

left=${displays[0]}
echo -n "$left"
for next_display in "${displays[@]:1}"; do
    echo -n " | $next_display"
    [[ $left = $next_display ]] || xrandr --output $next_display --right-of $left
    left=$next_display
done
echo

[[ -z $primary ]] || xrandr --output $primary --primary
