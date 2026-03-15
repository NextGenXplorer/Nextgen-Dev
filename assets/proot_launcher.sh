#!/bin/sh
# proot_launcher.sh — Bootstrap script for PRoot Ubuntu environment
# Enhanced for Android: safe bind mounts, environment variables, and bash login

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export LANG=C.UTF-8
export TERM="${TERM:-xterm-256color}"

PROOT_BIN="$1"
ROOTFS="$2"
WORKSPACE_DIR="$3"

if [ -z "$PROOT_BIN" ] || [ -z "$ROOTFS" ]; then
    echo "Usage: proot_launcher.sh <proot_binary> <rootfs_dir> [workspace_dir]"
    exit 1
fi

if [ ! -f "$PROOT_BIN" ]; then
    echo "[proot_launcher] ERROR: proot binary not found at: $PROOT_BIN"
    exit 1
fi

if [ ! -d "$ROOTFS" ]; then
    echo "[proot_launcher] ERROR: rootfs directory not found at: $ROOTFS"
    exit 1
fi

# Create /tmp inside rootfs if it doesn't exist (needed by many tools)
mkdir -p "$ROOTFS/tmp"

# Prepare workspace bind if provided
WORKSPACE_BIND=""
if [ -n "$WORKSPACE_DIR" ]; then
    mkdir -p "$WORKSPACE_DIR"
    WORKSPACE_BIND="-b $WORKSPACE_DIR:/workspace"
fi

exec "$PROOT_BIN" \
    --link2symlink \
    -0 \
    -r "$ROOTFS" \
    -b /dev \
    -b /proc \
    -b /sys \
    -b /system \
    -b /data/data \
    -b /storage \
    -b /system/etc/resolv.conf:/etc/resolv.conf \
    $WORKSPACE_BIND \
    -b "$ROOTFS/tmp:/tmp" \
    -w "${WORKSPACE_DIR:-/root}" \
    /usr/bin/env -i \
        HOME=/root \
        USER=root \
        PWD="${WORKSPACE_DIR:-/root}" \
        TERM="${TERM:-xterm-256color}" \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        LANG=en_US.UTF-8 \
        /bin/bash --login
