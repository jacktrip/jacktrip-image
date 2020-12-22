#!/bin/bash -e

ini_ensure() {
    if [[ `grep "$1" "${ROOTFS_DIR}/boot/config.txt"` ]]; then
        sed -i.bak "s/$1/$2/" "${ROOTFS_DIR}/boot/config.txt"
    else
        echo $2 >> "${ROOTFS_DIR}/boot/config.txt"
    fi
}

ini_ensure '.*hdmi_force_hotplug=.*' 'hdmi_force_hotplug=1'
ini_ensure '.*dtparam=audio=.*' 'dtparam=audio=off'

mkdir -p "${ROOTFS_DIR}/var/lib/jacktrip"

install -m 644 files/asound.snd_rpi_hifiberry_dacplusadc.state		"${ROOTFS_DIR}/var/lib/jacktrip"
install -m 644 files/asound.snd_rpi_hifiberry_dacplusadcpro.state	"${ROOTFS_DIR}/var/lib/jacktrip"
install -m 644 files/asound.audioinjector-pi-soundcard.state		"${ROOTFS_DIR}/var/lib/jacktrip"
install -m 644 files/asound.USB\ Audio\ Device.state			"${ROOTFS_DIR}/var/lib/jacktrip"
install -m 644 files/asound.USB\ PnP\ Sound\ Device.state		"${ROOTFS_DIR}/var/lib/jacktrip"
install -m 644 files/jamulus.ini					"${ROOTFS_DIR}/var/lib/jacktrip"

install -m 755 files/jacktrip-init.sh		"${ROOTFS_DIR}/usr/local/bin"
install -m 755 files/jacktrip-patches.sh	"${ROOTFS_DIR}/usr/local/bin"
install -m 755 files/jacktrip-agent		"${ROOTFS_DIR}/usr/local/bin"
install -m 755 files/jacktrip			"${ROOTFS_DIR}/usr/local/bin"
install -m 755 files/jack_delay			"${ROOTFS_DIR}/usr/local/bin"
install -m 755 files/Jamulus			"${ROOTFS_DIR}/usr/local/bin"

install -m 644 files/jacktrip-patches.service	"${ROOTFS_DIR}/etc/systemd/system/"
install -m 644 files/jacktrip-init.service	"${ROOTFS_DIR}/etc/systemd/system/"
install -m 644 files/jacktrip-agent.service	"${ROOTFS_DIR}/etc/systemd/system/"
install -m 644 files/jacktrip-clock.service	"${ROOTFS_DIR}/etc/systemd/system/"
install -m 644 files/jamulus.service		"${ROOTFS_DIR}/etc/systemd/system/"
install -m 644 files/jacktrip.service		"${ROOTFS_DIR}/etc/systemd/system/"
install -m 644 files/jack.service		"${ROOTFS_DIR}/etc/systemd/system/"

if [ -f "${ROOTFS_DIR}/etc/security/limits.d/audio.conf.disabled" ]; then
    mv "${ROOTFS_DIR}/etc/security/limits.d/audio.conf.disabled" "${ROOTFS_DIR}/etc/security/limits.d/audio.conf"
fi

rm -f "${ROOTFS_DIR}/etc/cron.hourly/fake-hwclock"

echo "net.ipv4.ping_group_range = 0 2147483647" > "${ROOTFS_DIR}/etc/sysctl.d/20-ping-group.conf"

mkdir -p "${ROOTFS_DIR}/etc/jacktrip"
echo $(date "+%Y%m%d99") > "${ROOTFS_DIR}/etc/jacktrip/patch"

sed -i "s,.*WAIT_ONLINE_METHOD=.*,WAIT_ONLINE_METHOD=route," "${ROOTFS_DIR}/etc/default/networking"

sed -i "s,ExecStart=/usr/local/bin/jackd,ExecStart=/usr/bin/jackd," "${ROOTFS_DIR}/etc/systemd/system/jack.service"

cp "${ROOTFS_DIR}/lib/systemd/system/ntp.service" "${ROOTFS_DIR}/etc/systemd/system/ntp.service"
sed -i "s,^PrivateTmp=true,#PrivateTmp=true," "${ROOTFS_DIR}/etc/systemd/system/ntp.service"

on_chroot << EOF

useradd -r -M -N -G audio -s /usr/sbin/nologin jacktrip
useradd -r -M -N -G audio -s /usr/sbin/nologin jamulus

systemctl daemon-reload

systemctl enable jacktrip-patches
systemctl enable jacktrip-init
systemctl enable jacktrip-agent
systemctl enable jacktrip-clock
systemctl enable ifupdown-wait-online
systemctl enable ntp
systemctl enable ssh

systemctl set-default multi-user.target

EOF
