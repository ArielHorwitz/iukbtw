#! /bin/bash
set -e

APP_NAME=$(basename "$0")
ABOUT="Prompt the user for confirmation. Defaults to accept."
CLI=(
    -o "text;Prompt text (is passed through printcolor);Confirm?"
    -O "timeout;Timeout in seconds;;t"
    -f "deny;Deny by default;;d"
    -e "printcolor_args;Arguments for printcolor when printing text;;c"
)
CLI=$(spongecrab --name "$APP_NAME" --about "$ABOUT" "${CLI[@]}" -- "$@") || exit 1
eval "$CLI" || exit 1

if [[ -n $timeout ]]; then
    timeout_indicator="[${timeout}s]"
    timeout="-t $timeout"
fi

# Prompt
[[ -n $deny ]] && yesno="(y/N)" || yesno="(Y/n)"
printcolor -n "$text" ${printcolor_args[@]}
printf " \e[35m%s\e[2;37m%b\e[0m " "$yesno" "$timeout_indicator"

# Read
read -sn 1 $timeout answer || :

# Parse
if [[ -n $deny ]]; then
    # Deny by default (--deny)
    [[ -n $answer && "yY" == *$answer* ]] && fixed_answer='+' || fixed_answer='-'
else
    # Accept by default
    [[ -n $answer && "nN" == *$answer* ]] && fixed_answer='-' || fixed_answer='+'
fi

echo $fixed_answer
[[ $fixed_answer = '+' ]] && exit 0 || exit 1
