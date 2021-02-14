#!/bin/bash -e

# Updates for read-only
# See https://medium.com/swlh/make-your-raspberry-pi-file-system-read-only-raspbian-buster-c558694de79

on_chroot << ROOTEOF

# package updates
apt-get remove -y --purge triggerhappy logrotate dphys-swapfile
apt-get install -y busybox-syslogd
apt-get remove -y --purge rsyslog
apt-get autoremove --purge

# append kernel flags
sed -i'' -e "s,\(..*\),\1 fastboot noswap ro," /boot/cmdline.txt

# mount partitions (not proc) read-only
sed -i'' -e "s/\(OOTDEV=.*\)defaults/\1defaults,ro/" /etc/fstab

# extra entries for temporary file system
cat << EOF >>/etc/fstab
tmpfs        /tmp            tmpfs   nosuid,nodev         0       0
tmpfs        /var/log        tmpfs   nosuid,nodev         0       0
tmpfs        /var/tmp        tmpfs   nosuid,nodev         0       0
EOF

# move system files to temp filesystem
chmod a+w /tmp
rm -rf /var/lib/dhcp /var/lib/dhcpcd5 /var/spool /etc/resolv.conf
ln -s /tmp /var/lib/dhcp
ln -s /tmp /var/lib/dhcpcd5
ln -s /tmp /var/spool
touch /tmp/dhcpcd.resolv.conf
ln -s /tmp/dhcpcd.resolv.conf /etc/resolv.conf

# link random seed to tmpfs location
rm -f /var/lib/systemd/random-seed
ln -s /tmp/random-seed /var/lib/systemd/random-seed

# Update random seed service
echo 'ExecStartPre=/usr/bin/echo "" >/tmp/random-seed' >> /lib/systemd/system/systemd-random-seed.service

# Add bash commands to switch between read-only and read-write modes
cat << EOF >>/etc/bash.bashrc

# Commands for switching between read-only and read-write modes
set_bash_prompt() {
    fs_mode=$(mount | sed -n -e "s/^\/dev\/.* on \/ .*(\(r[w|o]\).*/\1/p")
    PS1='\[\033[01;32m\]\u@\h${fs_mode:+($fs_mode)}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
}
alias ro='sudo mount -o remount,ro / ; sudo mount -o remount,ro /boot'
alias rw='sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot'
PROMPT_COMMAND=set_bash_prompt
EOF

# Ensure system returns to read-only mode after logout
cat << EOF >>/etc/bash.bash_logout

# Return system to read-only mode after logout
mount -o remount,ro /
mount -o remount,ro /boot
EOF

ROOTEOF
