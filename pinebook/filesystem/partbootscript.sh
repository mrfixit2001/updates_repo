#!/bin/bash

# AUTHOR: MRFIXIT2001 - January 2019
# NOTES:
# ** THIS SCRIPT HAS ONLY BEEN TESTED ON THE DEBIAN ROOTFS BUILD BY MRFIXIT **
# mrfixit rockchip debian distro is setup to start as 2 partitions and this script generates a 3rd partition so that the resulting image is split into 3 partitions:
# 1 - boot partition - contains kernel, DTB, and extlinux
# 2 - system partition - everything specific to debian that isn't user-specific files settings
# 3 - home partition - partition mounted and dedicated to the "/home" folder for user-specific files and settings - automatically sized to be the full remaining size of the disk

# There is an option to force the script to use only two partitions. Simply type:
# sudo touch /usr/bin/2parts.touch
# and reboot. The script will remove the third partition, setup the system partition with the home folder, and resize it to be the full size of the disk
# WARNING: Anything you saved to /home after initial installation will be removed

# On boot, this script checks for the 3rd partition and if it doesn't exist then it creates and expands it to be the size of the available disk.
# It also updates extlinux on the boot partition because the boot partition ID changes when the partition table changes.

getHomePart() {
	# This grabs the last partition in the partition table, the home partition should be the last one, but we will later confirm it actually exists
	HOMEPART=$(echo "${DEVID}" | sed 's:.*/::')
	HOMEPART=$(lsblk --output NAME | grep ${HOMEPART}p | tail -1 | sed 's/.*-//' | tr -cd '[[:alnum:]]._-')
	HOMEPART=$(echo "${DEVID}" | cut -f1,2 -d'/')"/"$HOMEPART
	echo $HOMEPART
}

# First we get all the partition information
SYSPART=$(findmnt -n -o SOURCE /)
if echo $SYSPART | grep -qE 'p[0-9]$' ; then
	DEVID=$(echo $SYSPART | sed -e s+'p[0-9]$'+''+)
else
	DEVID=$(echo $SYSPART | sed -e s+'[0-9]$'++)
fi
BOOTPART=$(blkid | grep 'LABEL="BOOT"' | grep $DEVID | cut -d: -f1)
HOMEPART=$(getHomePart)

if [ -z $(findmnt -n -o SOURCE /boot) ] ; then
	# Mount the boot partition as readonly under /boot
	mount -r $BOOTPART /boot
fi

# Now we check to see if extlinux needs updating - the true partition written to it and not the placeholder
if [ -z "$(grep "root=${SYSPART}" /boot/extlinux/extlinux.conf)" ] ; then
	echo "Fixing extlinux..."
	mount -o remount,rw "$BOOTPART" /boot
	sed -i "s,\(.*root=\)[^ ]* \(.*\),\1$SYSPART \2,g" /boot/extlinux/extlinux.conf
	mount -o remount,ro /boot

	# Since this should only happen on the very first boot, let's also clear and generate SSH keys one time
	rm -rf /etc/ssh/ssh_host_*
	/usr/bin/ssh-keygen -A
fi

# If "/usr/bin/2parts_done.touch" exists, then don't do anything else because the system partition has already been grown to the size of the disk
if [ -f /usr/bin/2parts_done.touch ] ; then
	exit
fi

# The script will check if "/usr/bin/2parts.touch" exists, and if it does then it will remove the third partition and expand the third to full size
if [ -f /usr/bin/2parts.touch ] ; then
	# 2parts.touch found, so the user has requested we do not use a 3rd partition
	if test $SYSPART != $HOMEPART && test $BOOTPART != $HOMEPART ; then
		# Looks like the third partition exists, so let's delete it
		umount /home
		echo -e "d\n3\nw" | fdisk "${DEVID}"
	fi

	# Expand partition 2
	parted -s "${DEVID}" resizepart "${SYSPART: -1}" 100%
	resize2fs "${SYSPART}"
	touch /usr/bin/2parts_done.touch

	if [ -d /root/home_seed ] ; then
		# Move home_seed back to be used as the home folder
		rm /home -r
		mv /root/home_seed /home
	fi

	reboot
else
	# the 2parts file doesn't exist, so continue to verify 3rd partition and create if missing

	# Now we confirm the home partition has been created. If it hasn't, then we create it.
	if test $SYSPART = $HOMEPART || test $BOOTPART = $HOMEPART ; then
		echo "Creating new home partition..."
		if test -n $DEVID ; then
			# Get the starting location
			PARTSTART=$(parted -s "${DEVID}" -m unit b print free | tail -1 | grep -E 'free;$' | cut -d: -f 2)
			# echo $PARTSTART
			if test -n $PARTSTART ; then
				# Create the new partition
				parted -s "${DEVID}" -m unit b mkpart primary "${PARTSTART}" 100%
				HOMEPART=$(getHomePart)
				if test $SYSPART = $HOMEPART || test $BOOTPART = $HOMEPART ; then
					echo "Error creating new partition - after creation it was not found in the partition table"
				else
					echo "created ${HOMEPART}, formatting..."
					mkfs.ext4 "${HOMEPART}" -q -F -L home
					e2fsck -f -p "${HOMEPART}"

					# MOUNT THE NEW PARTITION AS SOMETHING OTHER THAN /home
					mkdir /newhome
					mount $HOMEPART /newhome
					# - COPY /home CONTENTS TO IT
					rsync -av /home/ /newhome
					# - UNMOUNT AND LATER REMOUNT OVER /home
					umount /newhome
					rm -r /newhome
					mv /home /root/home_seed
					mkdir /home
				fi
			else
				echo "Could not identify where to start new home partition - partition creation aborted"
			fi
		else
			echo "Could not identify the device ID to generate the new partition on."
		fi
	fi

	# Confirm the home partition exists and if so then mount it as /home
	if [ $SYSPART != $HOMEPART ] && [ $BOOTPART != $HOMEPART ] && [ -z $(findmnt -n -o SOURCE /home) ] ; then
		mount $HOMEPART /home
	fi
fi
