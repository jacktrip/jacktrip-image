#!/bin/bash
#
# JackTrip Raspberry Pi Image: Update Patches
# Copyright (c) 2020 JackTrip Foundation

CONFIG_DIR=/etc/jacktrip
PATCH_FILE="${CONFIG_DIR}/patch"
PATCH_BASE_URL="https://files.jacktrip.org/patches"
PATCH_JSON_URL="$PATCH_BASE_URL/index.json"

# apply a patch file
apply_patch() {
    cd /tmp || return 1
    wget -q -O patch-$1.tgz $PATCH_BASE_URL/patch-$1.tgz || return 1
    wget -q -O patch-$1.sha256 $PATCH_BASE_URL/patch-$1.sha256 || return 1
    sha256sum -c --quiet patch-$1.sha256 || return 1

    tar xfz patch-$1.tgz || return 1
    cd patch-$1 || return 1
    ./apply.sh || return 2

    cd /tmp
    rm -rf patch-$1
    rm -f patch-$1.tgz patch-$1.sha256

    echo $1 > $PATCH_FILE
    echo "Successfully applied patch $1"
    return 0
}

# check for and apply any new patches
check_patches() {
    # Get current patch version
    PATCH_VERSION="0"
    if [ -f "$PATCH_FILE" ]; then
        PATCH_VERSION=`cat $PATCH_FILE`
    fi
    echo "Current patch level: $PATCH_VERSION"

    # Get index summarizing patch files
    for i in {10..0}; do
        PATCH_JSON=$(curl -f --silent --show-error $PATCH_JSON_URL 2>&1)
        if [ $? -eq 0 ]; then
            break
        fi
        if [ $i -eq 0 ]; then
            echo "Failed to retrieve patches index (max retries exceeded)"
            return 1
        fi
        echo "Failed to retrieve patches index (will retry $i times): $PATCH_JSON"
        sleep 5
    done

    # Parse patch index
    PATCH_VERSIONS=$(echo $PATCH_JSON |jq ".[]")
    if [ $? -ne 0 ]; then
        echo "Failed to parse index.json"
        return 1
    fi

    # Ensure config directory exists
    if [ ! -d ${CONFIG_DIR} ]; then
        mkdir ${CONFIG_DIR}
    fi

    # Apply any new patches
    APPLIED_PATCH=0
    PATCH_VERSIONS=$(echo $PATCH_VERSIONS |sort)
    for version in $PATCH_VERSIONS; do
        if [ ! `echo "$version" | grep "^[0-9]*$"` ]; then
            echo "Aborting due to invalid version"
            return 1
        elif [ $PATCH_VERSION -lt $version ]; then
            apply_patch $version
            if [ $? -ne 0 ]; then
                echo "Failed to apply patch for $version"
                return 1
            fi
            APPLIED_PATCH=1
        fi
    done

    if [ $APPLIED_PATCH -ne 1 ]; then
        echo "No new patches found"
    fi

    return 0
}

# Remount root read-write
mount -o remount,rw /

# main
check_patches

# Remount root read-only
sync
mount -o remount,ro /
