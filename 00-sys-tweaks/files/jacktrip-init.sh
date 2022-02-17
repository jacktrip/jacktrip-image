#!/bin/bash
#
# JackTrip Raspberry Pi Image: Initialization Service
# Copyright (c) 2020-2022 JackTrip Labs, Inc.

CONFIG_DIR=/etc/jacktrip
ETC_AVAHI_SERVICES_DIR=/etc/avahi/services
TMP_AVAHI_SERVICES_DIR=/tmp/avahi/services
DEVICENAME_FILE="${CONFIG_DIR}/devicename"
DEVICETYPE_FILE="${CONFIG_DIR}/devicetype"

# ensure that a line exists in /boot/config.txt
ini_ensure() {
    if [[ `grep "$1" "/boot/config.txt"` ]]; then
        sed -i.bak "s/$1/$2/" "/boot/config.txt"
    else
        echo $2 >> "/boot/config.txt"
    fi
}

# verify that a sound card is available via aplay command
function verify_card {
	echo "Checking for sound card NAME=$1 TYPE=$2"
	verify=$(aplay -l 2> /dev/null | grep "$1 \[${2}\]")
	if [ "$verify" != "" ]; then
		DEVICENAME="$1"
		DEVICETYPE="$2"
	fi
}

# add kernel overlay
function add_overlay {
	echo "Testing overlay $1"
	dtoverlay $1
	sleep 5
}

# remove kernel overlay
function remove_overlay {
	echo "Removing overlay $1"
	dtoverlay -R $1
	OVERLAYS="$1"
	while [ "$OVERLAYS" != "" ]; do
		sleep 1
		OVERLAYS=$(dtoverlay -l | grep "$1")
	done
}

# check for /proc/device-tree/hat
function check_hat {
	if [ -f /proc/device-tree/hat/product ]; then
		HATCARD=`cat /proc/device-tree/hat/product`
	else
		HATCARD=""
	fi
}

# detect supported alsa sound card
function detect_card {
	# Assume that the first ALSA card is the one we want to use (if it exists)
	DEVICETYPE=$(aplay -l 2> /dev/null | grep -m 1 'card [0-9]\+:' | sed 's/card [0-9]\+: \([^]]\+\) \[\([^]]\+\)\].*$/\2/')
	DEVICENAME=$(aplay -l 2> /dev/null | grep -m 1 'card [0-9]\+:' | sed 's/card [0-9]\+: \([^]]\+\) \[\([^]]\+\)\].*$/\1/')
}

# detect supported sound card (prefer HAT)
function detect_hat {
	check_hat

	# check if HiFiBerry DAC+ ADC Pro is already configured
	verify_card "sndrpihifiberry" "snd_rpi_hifiberry_dacplusadcpro"
	if [ "$DEVICETYPE" != "" ]; then
		# Set headphone amp volume for Stage
		i2cset -y 1 0x60 0x01 0xc0 2>/dev/null || true
		i2cset -y 1 0x60 0x02 0x31 2>/dev/null || true
		return
	fi

	# Check i2cget for HiFiBerry DAC+ ADC Pro
	if [ "$HATCARD" != "DAC+ ADC Pro" ]; then
		res=`i2cget -y 1 0x4a 25 2>/dev/null || true`
		if [ "$res" == "0x00" ]; then
			HATCARD="DAC+ ADC Pro"
		fi
	fi

	# Check HiFiBerry DAC+ ADC Pro (setup via HAT EEPROM)
	if [ "$HATCARD" == "DAC+ ADC Pro" ]; then
		echo "Detected HiFiBerry DAC+ ADC Pro"

		# check if enabled in /boot/config.txt
		if [ `grep "^dtoverlay=hifiberry-dacplusadcpro" /boot/config.txt` ]; then
			echo "Failed to load overlay for HiFiBerry DAC+ ADC Pro"
			return
		fi

		# try enabling overlay
		ini_ensure '.*dtoverlay=hifiberry.*' 'dtoverlay=hifiberry-dacplusadcpro'
		sync
		sleep 5
		reboot
	else
		if [ `grep "^dtoverlay=hifiberry-dacplusadcpro" /boot/config.txt` ]; then
		        sed -i.bak "s/^dtoverlay=hifiberry-dacplusadcpro/#dtoverlay=hifiberry-dacplusadcpro/" "/boot/config.txt"
		fi
	fi

	detect_card
	if [ "$DEVICETYPE" != "" ]; then
		return
	fi

	if [ "$HATCARD" != "" ]; then
		return -1
	fi

	# Check HiFiBerry DAC+ ADC Std (via dtoverlay dynamic load)
	add_overlay hifiberry-dacplusadc
	verify_card "sndrpihifiberry" "snd_rpi_hifiberry_dacplusadc"
	if [ "$DEVICETYPE" != "" ]; then
		return
	fi
	remove_overlay hifiberry-dacplusadc
	
	# Check HiFiBerry DIGI (via dtoverlay dynamic load)
	add_overlay hifiberry-digi
	verify_card "sndrpihifiberry" "snd_rpi_hifiberry_digi"
	if [ "$DEVICETYPE" != "" ]; then
		return
	fi
	remove_overlay hifiberry-digi

	# Check Audio Injector Stereo (via dtoverlay dynamic load)
	add_overlay audioinjector-wm8731-audio
	verify_card "audioinjectorpi" "audioinjector-pi-soundcard"
	if [ "$DEVICETYPE" != "" ]; then
		return
	fi
	remove_overlay audioinjector-wm8731-audio

	return -1
}

# turn off red and green lights
function leds_off {
	echo 0 > /sys/class/leds/led0/brightness
	echo 0 > /sys/class/leds/led1/brightness
}

# turn on red and green lights
function leds_on {
	echo 1 > /sys/class/leds/led0/brightness
	echo 1 > /sys/class/leds/led1/brightness
}

# turn on red and green lights
function leds_flip {
	STATUS=`cat /sys/class/leds/led0/brightness`
	if [ "$STATUS" == "0" ]; then
		leds_on
	else
		leds_off
	fi
}

# update sound device
function update_device {

	# Detect sound card
	detect_hat

	# Keep trying, so that a USB device can later be plugged in
	while [ "$DEVICETYPE" == "" ]; do
		echo "Unable to detect sound device"
		leds_flip
		sleep 5
		detect_card
	done

	# Ensure config directory exists
	if [ ! -d ${CONFIG_DIR} ]; then
		mkdir ${CONFIG_DIR}
	fi

	# Update device config files, if necessary
	if [ "$(cat ${DEVICENAME_FILE} 2> /dev/null)" != "$DEVICENAME" ]; then
		echo "Updating ${DEVICENAME_FILE}"
		echo $DEVICENAME > ${DEVICENAME_FILE}
	fi
	if [ "$(cat ${DEVICETYPE_FILE} 2> /dev/null)" != "$DEVICETYPE" ]; then
		echo "Updating ${DEVICETYPE_FILE}"
		echo $DEVICETYPE > ${DEVICETYPE_FILE}
	fi

	# Show results
	echo "Found sound device NAME=$DEVICENAME TYPE=$DEVICETYPE"
	aplay -l
	leds_on
}

# update /etc/issue
function update_issue {
	IP=$(hostname -I) || true
	MAC=$(cat /sys/class/net/eth0/address) || true
	APLAY=$(/usr/bin/aplay -l)
	VERSION=$(cat /etc/jacktrip/patch)

	if [ "$APLAY" == "" ]; then
		APLAY="No sound card found"
	fi

	cat << EOF >/etc/issue
Raspbian GNU/Linux 10 \\n \\l

JackTrip Image $VERSION
My IP address is $IP
My MAC address is $MAC

$APLAY

EOF
}

# update avahi services directory
function update_avahi_services {
	# Ensure etc services directory exists
	if [ ! -d ${ETC_AVAHI_SERVICES_DIR} ]; then
		mkdir -p ${ETC_AVAHI_SERVICES_DIR}
	fi

	# Ensure tmp services directory exists
	if [ ! -d ${TMP_AVAHI_SERVICES_DIR} ]; then
		mkdir -p ${TMP_AVAHI_SERVICES_DIR}

		# bind mount tmp services to etc services
		mount --bind $TMP_AVAHI_SERVICES_DIR $ETC_AVAHI_SERVICES_DIR
		#systemctl restart avahi-daemon
	fi

	# make sure ssh service file exists in tmp
	if [ ! -f "${TMP_AVAHI_SERVICES_DIR}/ssh.service" ]; then
		cp "/usr/share/doc/avahi-daemon/examples/ssh.service" "${TMP_AVAHI_SERVICES_DIR}/ssh.service"
	fi
}


# Remount volumes read-write
mount -o remount,rw /
mount -o remount,rw /boot

# initialize config and services
update_issue
update_avahi_services
update_device

# Remount volumes read-only
sync
mount -o remount,ro /
mount -o remount,ro /boot
