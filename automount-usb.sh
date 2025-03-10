#!/bin/bash

#
# psx-pi-smbshare automout-usb script
#
# *What it does*
# This script configures raspbian to automount any usb storage to /media/sd<xy>
# This allows for use of USB & HDD in addition to Micro-SD
# It also creates a new Samba configuration which exposes the last attached USB drive @ //SMBSHARE/<PARTITION>

# Update packages
opkg update

# Install NTFS Read/Write Support
opkg install ntfs-3g

# Install pmount with ExFAT support
opkg install exfat-fuse exfat-utils autoconf intltool libtool libtool-bin libglib2.0-dev libblkid-dev
cd ~
git clone https://github.com/stigi/pmount-exfat.git
cd pmount-exfat
./autogen.sh
make
make install prefix=usr
sed -i 's/not_physically_logged_allow = no/not_physically_logged_allow = yes/' /etc/pmount.conf

# Create udev rule
cat <<'EOF' | tee /etc/udev/rules.d/usbstick.rules
ACTION=="add", KERNEL=="sd[a-z][0-9]", TAG+="systemd", ENV{SYSTEMD_WANTS}="usbstick-handler@%k"
ENV{DEVTYPE}=="usb_device", ACTION=="remove", SUBSYSTEM=="usb", RUN+="/bin/systemctl --no-block restart usbstick-cleanup@%k.service"
EOF

# Configure systemd
cat <<'EOF' | tee /lib/systemd/system/usbstick-handler@.service
[Unit]
Description=Mount USB sticks
BindsTo=dev-%i.device
After=dev-%i.device

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/automount.sh %I
ExecStop=/usr/bin/pumount /dev/%I
EOF

cat <<'EOF' | tee /lib/systemd/system/usbstick-cleanup@.service
[Unit]
Description=Cleanup USB sticks
BindsTo=dev-%i.device

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/clear_usb.sh
EOF

# Configure script to run when an automount event is triggered
cat <<'EOF' | tee /usr/local/bin/automount.sh
#!/bin/bash

PART=$1
FS_LABEL=`lsblk -o name,label | grep ${PART} | awk '{print $2}'`

if [ -z ${PART} ]
then
    exit
fi

runuser pi -s /bin/bash -c "/usr/bin/pmount --umask 000 --noatime -w --sync /dev/${PART} /media/${PART}"
udpbd-server /media/${PART}
EOF

# Make script executable
chmod +x /usr/local/bin/automount.sh

# Reload udev rules and triggers
udevadm control --reload-rules && udevadm trigger
