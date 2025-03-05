#!/bin/bash

#
# psx-pi-smbshare setup script
#
# *What it does*
# It also configures the pi ethernet port to act as dhcp server for connected devices and allows those connections to route through wifi on wlan0
#
# *More about the network configuration*
# This configuration provides an ethernet connected PS2 or PS3 a low-latency connection to the smb share running on the raspberry pi
# The configuration also allows for outbound access from the PS2 or PS3 if wifi is configured on the pi
# This setup should work fine out the box with OPL and multiman
# Per default configuration, the smbserver is accessible on 192.168.2.1


USER=`whoami`

# Make sure we're not root otherwise the paths will be wrong
if [ $USER = "root" ]; then
  echo "Do not run this script as root or with sudo"
  exit 1
fi

# Update packages
opkg update
opkg upgrade

# Ensure basic tools are present
opkg install screen wget git curl coreutils

# Compile script
make -f /home/${USER}/udpbd-server/Makefile
chmod +x /home/${USER}/udpbd-server/udpbd-server
cp /home/${USER}/udpbd-server/udpbd-server /usr/local/bin

# Install and configure server
chmod 755 /home/${USER}/udpbd-server/clear_usb.sh
cp /home/${USER}/udpbd-server/clear_usb.sh /usr/local/bin

# Install wifi-to-eth route settings
#apt-get install -y dnsmasq
#chmod 755 /home/${USER}/udpbd-server/wifi-to-eth-route.sh

# Install USB automount settings
chmod 755 /home/${USER}/udpbd-server/automount-usb.sh
/home/${USER}/udpbd-server/automount-usb.sh

# Set samba-init + ps3netsrv, wifi-to-eth-route, setup-wifi-access-point, and XLink Kai to run on startup
# { echo -e "@reboot bash /usr/local/bin/samba-init.sh\n@reboot bash /home/${USER}/wifi-to-eth-route.sh"; } | crontab -u pi -
{ echo -e "@reboot bash /usr/local/bin/clear_usb.sh"; } | crontab -u pi -

# Start services
/usr/local/bin/clear_usb.sh
#/home/${USER}/udpbd-server/wifi-to-eth-route.sh
cat static_ip.txt >> /etc/dhcpcd.conf

# Not a bad idea to reboot
reboot
