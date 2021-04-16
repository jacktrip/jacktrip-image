#!/bin/sh
set -e

# Turn off LED status light triggers
echo none > /sys/class/leds/led0/trigger
echo none > /sys/class/leds/led1/trigger

# Turn GREEN=OFF, RED=ON
echo 0 > /sys/class/leds/led0/brightness
echo 1 > /sys/class/leds/led1/brightness

# Wait for default route to be available
WAIT_ONLINE_ADDRESS="default"
WAIT_ONLINE_TIMEOUT=300
(/usr/bin/timeout "$WAIT_ONLINE_TIMEOUT" /sbin/ip mon r & /sbin/ip -4 r s; /sbin/ip -6 r s) | /bin/grep -q "^$WAIT_ONLINE_ADDRESS\>"
