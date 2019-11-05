#!/bin/bash

printMsg() {
	echo
	echo $1
	sleep 0.5
}

# Script must be run as root
if (( $EUID != 0 )); then
	echo "Please run as root. Exiting..."
	sleep 3
	exit
fi

clear

# Get the model the update script is running on
MODEL=""
DTB=""
if grep -q "pinebook" "/sys/firmware/devicetree/base/compatible"; then
	MODEL="pinebook"
	DTB="rk3399-pinebookpro"
elif grep -q "rockpro" "/sys/firmware/devicetree/base/compatible"; then
	MODEL="rockpro"
	DTB="rk3399-rockpro64"
elif grep -q "rock64" "/sys/firmware/devicetree/base/compatible"; then
	MODEL="rock64"
	DTB="rk3328-rock64"
elif grep -q "rockbox" "/sys/firmware/devicetree/base/compatible"; then
	MODEL="rockbox"
	DTB="rk3328-rockbox"
else
	echo "Update Script Could Not Identify a Compatible Board"
	exit
fi

echo
echo "--==[* Welcome to the MrFixIt Update Script! *]==--"
echo This board identified as: ${MODEL}
echo
echo "This will check for and install kernel and filesystem updates."
read -p "Are you sure you want to continue (y/n)?" choice
case "$choice" in 
  y|Y ) clear;;
  n|N ) exit;;
  * ) echo "invalid selection, exiting"; exit;;
esac



printMsg "Making sure dependencies are in place..."
apt update -qq &> /dev/null
apt install -qq subversion curl &> /dev/null 

printMsg "Checking and Comparing this Board's Version..."
url="https://raw.github.com/mrfixit2001/updates_repo/master/${MODEL}/version"
curver=$( curl -# -L "${url}" 2> '/dev/null' )
myver="0.0"
if [ -f /usr/share/myver ]; then
	myver=$(cat /usr/share/myver)
fi
if [[ $curver == "" ]]; then
	curver=$myver
fi
if [[ $myver == $curver ]]; then
	clear
	printMsg "There are no new updates at this time. Please check again at a later date."
	echo
	echo "COMPLETED SUCCESSFULLY - NO UPDATES"
	sleep 5
	exit
else
	echo Update found: v${curver}
fi

printMsg "Creating Update Folder..."
UPDATE_FOLDER="/usr/share/mrfixit_updates"
mkdir -p ${UPDATE_FOLDER}

printMsg "Downloading the updates..."
url="https://github.com/mrfixit2001/updates_repo.git/branches/v${curver}/${MODEL}"
svn export ${url} ${UPDATE_FOLDER}/${curver}

printMsg "Handling file-system updates..."
if [ -f ${UPDATE_FOLDER}/${curver}/filesystem/mrfixit_update.sh ]; then
	chmod +x ${UPDATE_FOLDER}/${curver}/filesystem/mrfixit_update.sh
	${UPDATE_FOLDER}/${curver}/filesystem/mrfixit_update.sh
fi

printMsg "Handling kernel updates..."
BOOTPART=$(blkid | grep 'LABEL="BOOT"' | cut -d: -f1)
if [ -n "$BOOTPART" ]; then
	mount -o remount,rw "$BOOTPART" /boot
	if [ -f ${UPDATE_FOLDER}/${curver}/kernel/Image ]; then
		mv /boot/Image /boot/Image.bak
		cp ${UPDATE_FOLDER}/${curver}/kernel/Image /boot/Image
	fi
        if [ -f ${UPDATE_FOLDER}/${curver}/kernel/${DTB}.dtb ]; then
                mv /boot/${DTB}.dtb /boot/${DTB}.dtb.bak
                cp ${UPDATE_FOLDER}/${curver}/kernel/${DTB}.dtb /boot/${DTB}.dtb
        fi
        if [ -f ${UPDATE_FOLDER}/${curver}/kernel/extlinux.conf ]; then
                mv /boot/extlinux/extlinux.conf /boot/extlinux/extlinux.conf.bak
                cp ${UPDATE_FOLDER}/${curver}/kernel/extlinux.conf /boot/extlinux/extlinux.conf
        fi
	mount -o remount,ro /boot
fi

printMsg "Cleaning up..." 
rm ${UPDATE_FOLDER} -r
echo ${curver} > /usr/share/myver


printMsg "Congratulations - Update Completed Successfully!!"
printMsg "PLEASE REBOOT FOR THESE CHANGES TO TAKE EFFECT"
sleep 15
