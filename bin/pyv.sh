#! /bin/bash
set -e

USER_ENV=~/.local/share/pyv
USER_VENV=~/.local/share/pyv/base_venv
CURRENT_DIR=$(basename $(pwd))

APP_NAME=$(basename "$0")
ABOUT="Create and activate virtual environments for Python using virtualenv."
CLI=(
    --prefix "args_"
    -o "name;Create a new named virtual environment"
    -O "dir;Name for new virtual environment directoy;venv;d"
    -O "python_version;Python version to use;;p"
    -f "uninstall;Remove the default environment used for pyv;;U"
    -e "virtualenv_args;Arguments for virtualenv"
)
CLI=$(spongecrab --name "$APP_NAME" --about "$ABOUT" "${CLI[@]}" -- "$@") || exit 1
eval "$CLI" || exit 1

# Shortcut operations
if [[ -n $args_uninstall ]]; then
    rm -rf $USER_ENV
    exit 0
fi

# Install
if [[ ! -d $USER_VENV ]]; then
    mkdir --parent $USER_ENV
    python -m venv $USER_VENV
    source $USER_VENV/bin/activate
    pip install --upgrade pip virtualenv >/dev/null
    printcolor -s ok "Installed pyv at: $USER_ENV"
fi

source $USER_VENV/bin/activate || exit_error "Failed to activate pyv. Try (--install)"

if [[ -n $args_name ]]; then
    # Create new
    [[ ! -d $args_dir ]] || exit_error "Directory already exists"
    # Select python version
    if [[ -n $args_python_version ]]; then
        args_virtualenv_args+=("--python python${args_python_version}")
    fi
    # Create venv
    virtualenv $args_virtualenv_args --prompt $args_name $args_dir
    # Activate
    source $args_dir/bin/activate
    # Update pip
    pip install --upgrade pip
    # Print environment path
    printcolor -s notice "New venv: $VIRTUAL_ENV"
    exit
elif [[ -n $args_virtualenv_args ]]; then
    # Manage pyv environment
    printcolor -s notice "pyv venv: $VIRTUAL_ENV"
    virtualenv "${args_virtualenv_args[@]}"
else
    exit_error "No operation selected (try --help)."
fi
