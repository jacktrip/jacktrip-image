# JackTrip Raspberry Pi Image

```
# Clone pi-gen repository
git clone https://github.com/RPi-Distro/pi-gen.git

# Clone this repository as a subdirectory
cd pi-gen && git clone git@github.com:jacktrip/jacktrip-image.git

# Grab the latest binary files
wget -q -O - https://files.jacktrip.org/binaries/jacktrip-image-files-20210916.tar.gz |tar -C jacktrip-image/00-sys-tweaks/files -xzvf -

# Copy pi-gen config file
cp jacktrip-image/config .

# Apply patch to pi-gen stages
patch -p1 < jacktrip-image/pi-gen.patch

# Build image using a docker container
sudo ./build-docker.sh
```
