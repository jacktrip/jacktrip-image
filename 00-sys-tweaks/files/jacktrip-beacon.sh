#!/bin/bash
#
# JackTrip Raspberry Pi Image: Bluetooth Beacon Service
# Copyright (c) 2021 JackTrip Labs Inc

MACADDR=`cat /sys/class/net/eth0/address`

# Set bluetooth device name
#if [ ! -f /etc/machine-info ]; then
#	echo "PRETTY_HOSTNAME=\"JackTrip ${MACADDR}\"" > /etc/machine-info
#	systemctl restart bluetooth
#	hciconfig hci0 up
#fi

# Advertise Eddystone URL beacon for the device
EDDYSTONE_BASE="1F 02 01 06 03 03 aa fe 17 16 aa fe 10 00 03"
JKTP_NET_BASE="6a 6b 74 70 03"
MACBASE64=`echo ${MACADDR} | xxd -r -p | base64`
APISALT=`head -c3 /etc/jacktrip/credentials`
URLDATA=`echo "d${MACBASE64}${APISALT}" | hexdump -v -e '/1 "%02x "' -n 12`

hcitool -i hci0 cmd 0x08 0x0008 ${EDDYSTONE_BASE} ${JKTP_NET_BASE} ${URLDATA}
echo "Broadcasting BLE Eddystone Beacon: https://jktp.net/d${MACBASE64}${APISALT}"

# Advertise but don't allow connections
hciconfig hci0 leadv 3
hciconfig hci0 noscan
