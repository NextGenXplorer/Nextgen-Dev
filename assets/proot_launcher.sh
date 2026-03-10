#!/bin/sh
# proot_launcher.sh - Bootstrap script for PRoot Ubuntu environment
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export LANG=C.UTF-8

# Initialize proot with rootfs provided in arguments
PROOT_BIN=$1
ROOTFS=$2

if [ -z "$PROOT_BIN" ] || [ -z "$ROOTFS" ]; then
    echo "Usage: ./proot_launcher.sh <path_to_proot> <path_to_rootfs>"
    exit 1
fi

# Switch to pseudo-root using proot and spawn a shell
# Bind critical directories to make it a fully functional environment
exec $PROOT_BIN \
    --link2symlink \
    -0 \
    -r $ROOTFS \
    -b /dev \
    -b /sys \
    -b /proc \
    -b /storage \
    -b /sdcard \
    -w /root \
    /usr/bin/env -i \
    HOME=/root \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    TERM=$TERM \
    LANG=C.UTF-8 \
    /bin/bash -l
