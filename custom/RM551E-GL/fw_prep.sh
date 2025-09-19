#!/bin/ash

# Define toolkit paths
GITUSER="iamromulan"
GITREPO="quectel-rgmii-toolkit"
GITTREE="SDXPINN"
GITMAINTREE="SDXPINN"
GITDEVTREE="development-SDXPINN"
#FWBRANCH="R01"
FWBRANCH="R02"

# Function to remount file system as read-write
remount_rw() {
    mount -o remount,rw /
}

# Function to remount file system as read-only
remount_ro() {
    mount -o remount,ro /
}

prep_sysfs() {
	remount_rw
	#umount -lf /etc
	#umount -lf /etc
	#umount -lf /data
	#touch /usrdata/etc/merged.done
	mkdir /usrdata/overlay-work
	mkdir /usrdata/overlay-work/etc-upper
	touch /usrdata/overlay-work/etc-upper/merged.done
	cd /tmp
	# Check if /etc/opkg.conf has a line containing "option overlay_root /overlay" and remove it if it exists
    	/bin/echo "Lets be sure your opkg config isn't using the old overlay"
    	if grep -q "option overlay_root /overlay" /etc/opkg.conf; then
        	/bin/echo "Removing 'option overlay_root /overlay' from /etc/opkg.conf"
        	sed -i '/option overlay_root \/overlay/d' /etc/opkg.conf
    	else
       	 /bin/echo "'option overlay_root /overlay' not found in /etc/opkg.conf, no changes made"
    	fi

	curl -O https://raw.githubusercontent.com/$GITUSER/$GITREPO/$GITTREE/opkg-feed/sdxpinn-patch_2.6_all.ipk
    	opkg install ./sdxpinn-patch_2.6_all.ipk
	opkg update
    	echo -e "\e[92m"
	echo "iamromulan's ipk/opkg repo added!"
    	echo "Installing basic packages..."
	opkg install atinout luci-app-atinout-mod mc-skins sdxpinn-console-menu luci-app-ttyd kmod-wireguard
    	echo "Patching default Quectel login binary..."
        echo -e "\e[0m"
	# Get rid of the Quectel Login Binary
	opkg install shadow-login
	mv /bin/login /bin/login.old
	cp /usr/bin/login /bin/login
	# Pre-set root password as iamromulan
	echo -e "iamromulan\niamromulan" | passwd root

    # Check and download /etc/init.d/dropbear if missing
    [ -f /etc/init.d/dropbear ] || { 
        curl -o /etc/init.d/dropbear https://raw.githubusercontent.com/$GITUSER/$GITREPO/$GITTREE/missing/dropbear &&
        chmod +x /etc/init.d/dropbear; 
    }

    # Check and download /etc/init.d/uhttpd if missing
    [ -f /etc/init.d/uhttpd ] || { 
        curl -o /etc/init.d/uhttpd https://raw.githubusercontent.com/$GITUSER/$GITREPO/$GITTREE/missing/uhttpd &&
        chmod +x /etc/init.d/uhttpd; 
    }


	service uhttpd enable
	service dropbear enable
	service uhttpd start
	service dropbear start
    	
    	echo "Stage 1 sysfs-prep complete!"
    	echo "Visit https://github.com/iamromulan for more!"
    	echo -e "\e[0m"
}

prep_final_sysfs() {
echo "Begin Final sysfs prep"
opkg update
echo "Arming first-boot init"
# Install first boot init
opkg install sdxpinn-firstboot
echo "Installing mount-fix"
# Install mount-fix
opkg install sdxpinn-mount-fix
echo "Stage 2 sysfs-prep complete!"
echo "Visit https://github.com/iamromulan for more!"

}

prep_usrdata() {
	echo "Disabled"
	return
	opkg update
    	echo -e "\e[92m"
	echo "Nah"
    	
    	echo "sysfs-prep complete!"
    	echo "Visit https://github.com/iamromulan for more!"
    	echo -e "\e[0m"
}

capture() {
	mount -o remount,ro /real_rootfs
	mount -o remount,ro /etc/rc.d
    	echo -e "\e[92m"
    	#For R01
	#dd if=/dev/mtd35 of=/usrdata/sysfs.ubi bs=4096
	#For R02
	dd if=/dev/mtd55 of=/usrdata/sysfs.ubi bs=4096
	#For edits after mount-fix is in place
    	#tar -czf /usrdata/usrdata.tar.gz /usrdata/rootfs /usrdata/rootfs-workdir
    	echo "Capture complete!"
    	echo "Now do..."
    	echo "adb pull /usrdata/sysfs.ubi"
    	#echo "adb pull /usrdata/usrdata.tar.gz"
    	echo "Visit https://github.com/iamromulan for more!"
    	echo -e "\e[0m"
}

# Main menu
while true; do
echo "                                  :@@@@-                     "
echo "                                      -@@@@#.                "
echo "      .+-                                #@@@@%.+@-          "
echo "    -@*@*@%                                @@@@@::@@=        "
echo "    .@@@@@:                                :@@@@@ =@@@..%=   "
echo "      .%-                                  -@@@@@:=@@@@  @@# "
echo "      .*-            .@@@@@@@@@@=.         @@@@@@ @@@@@  @@@:"
echo "                        -@@@@@@@@@@@@@@@..@@@@@@.-@@@@@ .@@@-"
echo "                           =@@@@@@@@*  .@@@@@@. @@@@@@..@@@@-"
echo "                            @@@@@@:.-@@@@@@.  @@@@@@= %@@@@@."
echo "                           %@@. =@@@@@*.  +@@@@@@%.-@@@@@@%  "
echo "                          =@.+@@@@@. -@@@@@@@*.:@@@@@@@*.    "
echo "                          ..@@@@= .@@@@@@: #@@@@@@@:         "
echo "                           .@@@.  @@@@.:@@@@+.               "
echo "                            :@@@  %@@..@@#.    *@            "
echo "                       =@@@@@@.*@- :@%  @* =@:=@#            "
echo "                      .@@.  @@-%@:      .%@@*@@%.            "
echo "                                  .*@@@:=@@@@:               "
echo "                             #@@@@: =@@@@@-                  "
echo "                         -@@@@@  @@@@@@%                     "
echo "                        :@@@@# =@@@@@@%                      "
echo "                        *@@@@  @@@@@@@.                      "
echo "                         #@@@. @@@@@@*                       "
echo "                                *@@@@@@                      "
echo "                                  .@@@@@@.                   "
echo "                                      .=@@@@@-               "


    echo -e "\e[92m"
    echo "Firmware prep script for SDXPINN"
    echo "Visit https://github.com/iamromulan for more!"
    echo -e "\e[0m"
    echo "Select an option:"
    echo -e "\e[0m"
    echo -e "\e[96m1) Prep-sysfs\e[0m" # Cyan
    echo -e "\e[93m2) Final Prep-sysfs\e[0m" # Yellow
    echo -e "\e[92m3) Prep-usrdata\e[0m" # Green
    echo -e "\e[94m4) Capture\e[0m" # Light Blue
    echo -e "\e[93m5) Exit\e[0m" # Yellow (repeated color for exit option)
    read -p "Enter your choice: " choice

    case $choice in
        1) prep_sysfs ;;
        2) prep_final_sysfs ;;
        3) prep_usrdata ;;
        4) capture ;;   
        5) echo -e "\e[1;32mGoodbye!\e[0m"; break ;;
        *) echo -e "\e[1;31mInvalid option\e[0m" ;;
    esac
done


