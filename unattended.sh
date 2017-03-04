########################################################################################
# Installation procedure for the Raspberry Pi - IP Camera
########################################################################################

# This procedure was designed on top of a foundation Raspbian Jessie lite image with build date 10-05-2016
# Download the latest Raspbian Jessie Lite image from https://downloads.raspberrypi.org/raspbian_lite_latest
# Unzip your downloaded image, and write it to SD card with win32 disk imager.
# Boot up your SD card in your Raspberry Pi, and Log into the Raspbian Jessie OS, with pi as username and raspberry as password.
# Start executing below commands in sequence.

########################################################################################
# Bootstrap - Preparing the Raspbian OS.
########################################################################################
# Regen our security keys, it's a best practice
sudo /bin/rm -v /etc/ssh/ssh_host_*
sudo ssh-keygen -t dsa -N "" -f /etc/ssh/ssh_host_dsa_key
sudo ssh-keygen -t rsa -N "" -f /etc/ssh/ssh_host_rsa_key
sudo ssh-keygen -t ecdsa -N "" -f /etc/ssh/ssh_host_ecdsa_key
sudo ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
sudo systemctl restart sshd.service

########################################################################################
# Update Firmware - Making sure that your Raspbian firmware is the latest version.
########################################################################################
# update raspbian
sudo apt-get update && sudo apt-get -y dist-upgrade

########################################################################################
# Download a copy of our git repository and extract it.
########################################################################################
wget -O /home/pi/RaspberryIPCamera.zip https://github.com/ronnyvdbr/RaspberryIPCamera/archive/v1.7-beta.zip
unzip /home/pi/RaspberryIPCamera.zip -d /home/pi
rm /home/pi/RaspberryIPCamera.zip
mv /home/pi/RaspberryIPCamera* /home/pi/RaspberryIPCamera

########################################################################################
# Set-up nginx with php support and enable our Raspberry IP Camera website.
########################################################################################
# Install nginx with php support.
sudo apt-get -y install nginx php5-fpm
# Disable the default nginx website.
sudo rm /etc/nginx/sites-enabled/default
# Copy our siteconf into place
sudo cp /home/pi/RaspberryIPCamera/DefaultConfigFiles/RaspberryIPCamera.Nginx.Siteconf /etc/nginx/sites-available/RaspberryIPCamera.Nginx.Siteconf
# Lets enable our website
sudo ln -s /etc/nginx/sites-available/RaspberryIPCamera.Nginx.Siteconf /etc/nginx/sites-enabled/RaspberryIPCamera.Nginx.Siteconf
# Disable output buffering in php.
sudo sed -i 's/output_buffering = 4096/;output_buffering = 4096/g' /etc/php5/fpm/php.ini
# Set permissions for the config files
sudo chgrp www-data /home/pi/RaspberryIPCamera/www/RaspberryIPCameraSettings.ini
chmod 664 /home/pi/RaspberryIPCamera/www/RaspberryIPCameraSettings.ini
sudo chgrp www-data /home/pi/RaspberryIPCamera/secret/RaspberryIPCamera.secret
chmod 664 /home/pi/RaspberryIPCamera/secret/RaspberryIPCamera.secret

########################################################################################
# Enable our Raspberry Pi Camera Module in our boot configuration.
########################################################################################
echo "disable_camera_led=1" | sudo tee -a /boot/config.txt

########################################################################################
# Install all UV4L components
########################################################################################
# Add the supplier's repository key to our key database
curl http://www.linux-projects.org/listing/uv4l_repo/lrkey.asc | sudo apt-key add -
echo "deb http://www.linux-projects.org/listing/uv4l_repo/raspbian/ jessie main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
# Now fetch and install the required modules.
sudo apt-get -y install uv4l uv4l-raspicam
sudo apt-get -y install uv4l-raspicam-extras
sudo apt-get -y install uv4l-server
# Let's copy our own config files in place.
sudo cp /home/pi/RaspberryIPCamera/DefaultConfigFiles/uv4l-raspicam.conf /etc/uv4l/uv4l-raspicam.conf
sudo cp /home/pi/RaspberryIPCamera/DefaultConfigFiles/uv4l-server.conf /etc/uv4l/uv4l-server.conf
sudo sed -i "s/--editable-config-file=\$CONFIGFILE/--server-config-file=\/etc\/uv4l\/uv4l-server.conf/g" /etc/init.d/uv4l_raspicam
# Notify systemd of service changes.
sudo systemctl daemon-reload
# Set some permissions so our web gui can modify the config files.
sudo chgrp www-data /etc/uv4l/uv4l-raspicam.conf
sudo chmod 664 /etc/uv4l/uv4l-raspicam.conf

########################################################################################
# Install the RTSP server
########################################################################################
# we will be compiling software, so install some prerequisite
sudo apt-get -y install cmake libasound2-dev
# first compile the live555 library as a prerequisite
wget http://www.live555.com/liveMedia/public/live555-latest.tar.gz -O - | tar xvzf -
cd live
./genMakefiles linux
sudo make CPPFLAGS=-DALLOW_RTSP_SERVER_PORT_REUSE=1 install
cd ..
# clone the rtsp server's git repository, compile and install
sudo apt-get -y install git
git clone https://github.com/mpromonet/v4l2rtspserver.git
sudo apt-get install -y libasound2-dev liblog4cpp5-dev liblivemedia-dev
cd v4l2rtspserver
cmake . && make
sudo make install

# Put system service file for RTSP server into place
sudo cp /home/pi/RaspberryIPCamera/DefaultConfigFiles/RTSP-Server.service /etc/systemd/system/RTSP-Server.service
# Notify systemd of a service installation.
sudo systemctl daemon-reload
# Set the startup for the service to disabled for our default config.
sudo systemctl disable RTSP-Server.service


########################################################################################
# Set some additional rights and config files
########################################################################################
# put a sudoers file in the correct location for php shell commands integration
sudo cp /home/pi/RaspberryIPCamera/DefaultConfigFiles/sudoers_commands /etc/sudoers.d/sudoers_commands
# Put correct security rights on configuration files
sudo chgrp www-data /etc/timezone
sudo chmod 664 /etc/timezone
sudo chgrp www-data /etc/ntp.conf
sudo chmod 664 /etc/ntp.conf

########################################################################################
# Make our SD card read only, to preserve it and contribute to system stability
########################################################################################
# First get rid of some unnecessary pagkages.
sudo apt-get -y remove --purge cron logrotate triggerhappy dphys-swapfile fake-hwclock samba-common
sudo apt-get -y autoremove --purge
# remove rsyslog and install a memory resident variant
sudo apt-get -y remove --purge rsyslog
sudo apt-get -y install busybox-syslogd

########################################################################################
# Clean unneeded packages from our design to make the image size smaller for redistribution
########################################################################################
# Let's clean as much rubbish from our image so we can repack this for internet distribution in a normal size.
sudo apt-get -y install localepurge
sudo localepurge
sudo apt-get -y remove --purge localepurge
sudo apt-get -y remove --purge avahi-daemon build-essential nfs-common console-setup curl dosfstools lua5.1 luajit manpages-dev parted python-rpi.gpio python
sudo apt-get -y autoremove --purge
sudo apt-get clean

sudo reboot

