#! /bin/bash
set -e

DATADIR=$PWD/`dirname "$0"`
TMPDIR="/tmp/install-kmonad/"

BINARY_URL="https://github.com/kmonad/kmonad/releases/download/0.4.2/kmonad"

# Root
[[ $EUID -eq 0 ]] && exit_error "Do not run `basename $0` as root."
sudo printcolor -s ok "Root privileges aquired."

setup_installation() {
    # Temporary dir
    printcolor -s debug "Temporary working directory: $TMPDIR"
    rm -rf $TMPDIR
    mkdir -p $TMPDIR
    cd $TMPDIR
}

cleanup_installation() {
    printcolor -s ok "Cleaning up..."
    rm -rf $TMPDIR
}

install_binary() {
    # Download KMonad v0.4.2
    download_file=$TMPDIR/kmonad
    printcolor -s ok "Downloading..."
    echo "  $BINARY_URL"
    wget -q --output-document $download_file $BINARY_URL
    printcolor -s ok "Installing..."
    chmod +x $download_file
    sudo mv $download_file /bin/kmonad
}

configure() {
    printcolor -s ok "Configuring udev rules and uinput module..."
    # Add udev rules for KMonad
    # (https://github.com/kmonad/kmonad/blob/master/doc/faq.md#q-how-do-i-get-uinput-permissions)
    # (https://github.com/kmonad/kmonad/issues/160#issuecomment-766121884)
    sudo groupadd -f uinput
    sudo usermod -aG input,uinput $USER
    local rules='KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"'
    echo $rules | sudo tee /etc/udev/rules.d/90-uinput.rules >/dev/null
    echo 'uinput' | sudo tee /etc/modules-load.d/uinput.conf >/dev/null
    newgrp uinput
    newgrp input
}

setup_installation
install_binary
configure
cleanup_installation
