#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
myver="0.0"
if [ -f /usr/share/myver ]; then
        myver=$(cat /usr/share/myver)
fi

if [[ $myver < 1.2 ]]; then
	echo "Installing WiDevine Update Script Desktop Shortcut..."
	chown 1000:1000 $DIR/*.desktop
	chmod +x $DIR/*.desktop
	if [ -d "/home/rock/Desktop" ] ; then
		mv $DIR/*.desktop /home/rock/Desktop
	fi
	ID="$(id -nu 1000)"
	if [[ -d "/home/"$ID"/Desktop" && $ID != "rock" ]] ; then
		mv $DIR/*.desktop /home/$ID/Desktop
	fi
	mv $DIR/update_widevine.sh /usr/bin
fi

if [[ $myver < 1.5 ]]; then
	echo
	echo "Updating Chromium..."
	dpkg -i $DIR/chromium-codecs-ffmpeg-extra_78.0.3904.97-0ubuntu0.16.04.1_armhf.deb
	dpkg -i $DIR/chromium-browser_78.0.3904.97-0ubuntu0.16.04.1_armhf.deb

	# Update bootpartscript
	mv $DIR/partbootscript.sh /usr/bin
	chmod +x /usr/bin/partbootscript.sh

	# Disable wifi power management
	mv $DIR/rc.local /etc
	chmod +x /etc/rc.local
fi

if [[ $myver < 1.6 ]]; then
	# Fix firefox graphics acceleration
	for file in /home/*/.mozilla/firefox/*/prefs.js; do
		echo 'user_pref("gfx.xrender.enabled", true);' >> "$file"
	done
fi

if [[ $myver < 1.8 ]]; then
	echo "Installing Chromium Default Flags for Improved Performance..."
	mv $DIR/default /etc/chromium-browser
fi

if [[ $myver < 1.9 ]]; then
	echo "Updating Firefox..."
	dpkg -i $DIR/firefox_71.0+build5-0ubuntu0.16.04.1_armhf.deb

	echo "Fixing firefox sound..."
	for file in /home/*/.mozilla/firefox/*/prefs.js; do
		echo 'user_pref("media.cubeb.backend", "pulse");' >> "$file"
	done

	echo "Adding bluetooth packages to fix issues..."
	apt install -qq -y pulseaudio-module-bluetooth bluez-firmware &> /dev/null

	echo "Adding Community Wallpaper..."
	cp $DIR/bgs/* /usr/share/backgrounds
fi

if [[ $myver < 2.0 ]]; then
	# Leave the current kernel version's modules folder in place so that it can be used as the backup kernel
	echo "Updating Kernel Modules to 4.4.212..."
	KER="$(uname -r)"
	find /lib/modules -mindepth 1 ! -regex '^/lib/modules/'$KER'\(/.*\)?' -delete
	rm /lib/modules/4.4.212 -r
	mv $DIR/4.4.212 /lib/modules

	echo "Updating U-Boot..."
	SYSPART=$(findmnt -n -o SOURCE /)
	if echo $SYSPART | grep -qE 'p[0-9]$' ; then
		DEVID=$(echo $SYSPART | sed -e s+'p[0-9]$'+''+)
	else
		DEVID=$(echo $SYSPART | sed -e s+'[0-9]$'++)
	fi
	echo Identified $DEVID as device to flash uboot to...
	if [ -f $DIR/idbloader.img ] ; then
		echo "Upgrading idbloader.img..."
		dd if=$DIR/idbloader.img of=$DEVID bs=32k seek=1 conv=fsync &>/dev/null
	fi
	if [ -f $DIR/uboot.img ] ; then
		echo "Upgrading uboot.img..."
		dd if=$DIR/uboot.img of=$DEVID bs=64k seek=128 conv=fsync &>/dev/null
	fi
	if [ -f $DIR/trust.img ] ; then
		echo "Upgrading trust.img..."
		dd if=$DIR/trust.img of=$DEVID bs=64k seek=192 conv=fsync &>/dev/null
	fi

	echo
	echo "Running Boot Partition Cleanup Script..."
	chmod +x $DIR/cleanboot.sh
	$DIR/cleanboot.sh
fi

