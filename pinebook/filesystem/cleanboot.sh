#!/bin/bash

askUser() {
	echo
	echo "!!! WARNING !!!"
	echo "The following file is not part of the default install and MAY be malicious:"
	echo "  $1"
	echo
	echo "If you do not recognize this file, you should answer Y and remove it now."
	echo
	read -p "Do you want to remove this unexpected file now? (Y/n) " choice
	case "$choice" in
		y|Y|yes|YES|Yes )
			rm $1
			echo "File Removed.";;
		*)
			echo "File ignored";;
	esac
	echo "..."
	echo
}

mount /boot -o remount,rw
clear
echo "Scanning the boot partition for unknown files..."
for file in /boot/*; do
        case "$file" in
         /boot/rk3399-pinebookpro.dtb) 
		#echo "Found DTS"
		;;
         /boot/Image) 
		#echo "Found Kernel"
		;;
         /boot/extlinux) 
		#echo "Found extlinux"
		;;
         /boot/rk3399-pinebookpro.dtb.bak) 
		#echo "Found Backup DTS"
		;;
         /boot/Image.bak) 
		#echo "Found Backup Kernel"
		;;
         *)
		askUser $file
        esac
done

for file in /boot/extlinux/*; do
        case "$file" in
         /boot/extlinux/extlinux.conf) 
		#echo "Found extlinux.conf"
		;;
         *)
		askUser $file
        esac
done

echo "Scan Complete!"
mount /boot -o remount,ro
