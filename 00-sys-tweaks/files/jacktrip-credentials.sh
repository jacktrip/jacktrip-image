#!/bin/bash
#
# JackTrip Raspberry Pi Image: Credentials Service
# Copyright (c) 2020-2021 JackTrip Labs, Inc.

CONFIG_DIR=/etc/jacktrip
CREDENTIALS_FILE="${CONFIG_DIR}/credentials"

# get a random string (default 15). Optionally set a random length.
# random_string        -> 15 chars
# random_string 50     -> 50 chars
# random_string 20 80  -> will be between 20 and 80 chars long
# from https://www.supertechcrew.com/random-numbers-strings-bash-shell-scripting/#:~:text=Creating%20Random%20Numbers%20and%20Strings,--random-source=/dev/urandom%20-i%200-100%20-n%201
random_string() {
        local l=15
        [ -n "$1" ] && l=$1
        [ -n "$2" ] && l=$(shuf --random-source=/dev/urandom -i $1-$2 -n 1)
        tr -dc A-Za-z0-9 < /dev/urandom | head -c ${l} | xargs
}

# update API credentials, if necessary
if [ ! `grep "^[a-zA-Z0-9]*\.[a-zA-Z0-9]*$" ${CREDENTIALS_FILE}` ]; then
	echo "Generating new credentials file: ${CREDENTIALS_FILE}"
	API_PREFIX=`random_string 7`
	API_SECRET=`random_string 32`
	echo "${API_PREFIX}.${API_SECRET}" > ${CREDENTIALS_FILE}
fi
