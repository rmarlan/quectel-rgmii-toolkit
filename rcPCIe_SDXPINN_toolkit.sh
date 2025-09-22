#!/bin/ash

#WORK IN PROGRESS

# Define toolkit paths
GITUSER="iamromulan"
GITREPO="quectel-rgmii-toolkit"
GITTREE="SDXPINN"
GITMAINTREE="SDXPINN"
GITDEVTREE="development-SDXPINN"
TMP_DIR="/tmp"
USRDATA_DIR="/data"
SIMPLE_FIREWALL_DIR="/data/simplefirewall"
SIMPLE_FIREWALL_SCRIPT="$SIMPLE_FIREWALL_DIR/simplefirewall.sh"
SIMPLE_FIREWALL_SYSTEMD_DIR="$SIMPLE_FIREWALL_DIR/systemd"

# Function to remount file system as read-write
remount_rw() {
    mount -o remount,rw /
}

# Function to remount file system as read-only
remount_ro() {
    mount -o remount,ro /
}

send_at_commands_using_atcmd() {
    while true; do
        echo -e "\e[1;32mEnter AT command (or type 'exit' to return to the main menu): \e[0m"
        read at_command
        if [ "$at_command" = "exit" ]; then
            echo -e "\e[1;32mReturning to the main menu.\e[0m"
            break
        fi
        echo -e "\e[1;32mSending AT command: $at_command\e[0m"
        echo -e "\e[1;32mResponse:\e[0m"
        # Use atcmd to send the command and display the output
        atcmd_output=$(atcmd "'$at_command'")
        echo "$atcmd_output"
        echo -e "\e[1;32m----------------------------------------\e[0m"
    done
}


overlay_check() {
    if ! grep -qs '/real_rootfs ' /proc/mounts; then
        echo -e "\e[31mYou have not installed the sdxpinn-mount-fix!!! Please run option 2!!\e[0m"
        return 1
    fi
}

install_mount_fix() {
    # Check if neither /etc nor /real_rootfs is mounted
    if ! grep -qs '/etc ' /proc/mounts && ! grep -qs '/real_rootfs ' /proc/mounts; then
        # Echo message in red
        echo -e "\033[31mSomething is wrong or this is not an SDXPINN modem.\033[0m"
        echo -e "\033[31mI was expecting either /etc or /real_rootfs to be a mount point.\033[0m"
        exit 1
    fi
    # Install mount-fix
    cd /tmp
    curl -O https://raw.githubusercontent.com/$GITUSER/$GITREPO/$GITTREE/opkg-feed/sdxpinn-mount-fix_1.3.3_aarch64_cortex-a53.ipk
    opkg install sdxpinn-mount-fix_1.3.3_aarch64_cortex-a53.ipk
}

basic_55x_setup() {
    overlay_check || return
	cd /tmp
	curl -O https://raw.githubusercontent.com/$GITUSER/$GITREPO/$GITTREE/opkg-feed/sdxpinn-patch_2.6_all.ipk
    opkg install sdxpinn-patch_2.6_all.ipk
	opkg update
    	echo -e "\e[92m"
	echo "iamromulan's ipk/opkg repo added!"
    echo "Installing basic packages..."
	opkg install atinout luci-app-atinout-mod sdxpinn-console-menu
    echo "Patching default Quectel login binary..."
        echo -e "\e[0m"
	# Get rid of the Quectel Login Binary
	opkg install shadow-login
	mv /bin/login /bin/login.old
	cp /usr/bin/login /bin/login

	opkg install luci-app-ttyd
	opkg install mc-skins

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

    	echo "Basic packages installed!"
    	echo "Visit https://github.com/iamromulan for more!"
    	echo -e "\e[0m"
}

ttl_setup() {
  local ttl_file="/etc/firewall.user.ttl"
  local lan_utils_script="/etc/data/lanUtils.sh"
  local combine_function="util_combine_iptable_rules"
  local temp_file="/tmp/temp_firewall_user_ttl"

  overlay_check || return

  while true; do
    if [ ! -f "$ttl_file" ]; then
      echo "Creating $ttl_file..."
      touch "$ttl_file"

      echo "Modifying $combine_function in $lan_utils_script..."

      # Backup the original script
      cp "$lan_utils_script" "${lan_utils_script}.bak"

      # Add the local ttl_firewall_file line if it's not already present
      if ! grep -q "local ttl_firewall_file" "$lan_utils_script"; then
        sed -i '/local tcpmss_firewall_filev6/a \  local ttl_firewall_file=/etc/firewall.user.ttl' "$lan_utils_script"
      fi

      # Add the condition to include the ttl_firewall_file if it's not already present
      if (! grep -q "if \[ -f \"\$ttl_firewall_file\" \]; then" "$lan_utils_script"); then
        sed -i '/if \[ -f "\$tcpmss_firewall_filev6" \]; then/i \  if [ -f "\$ttl_firewall_file" ]; then\n    cat \$ttl_firewall_file >> \$firewall_file\n  fi' "$lan_utils_script"
      fi
    fi

    if [ ! -s "$ttl_file" ]; then
      echo -e "\e[31mTTL is not enabled\e[0m"
    else
      ipv4_ttl=$(grep 'iptables -t mangle -A POSTROUTING' "$ttl_file" | awk '{for(i=1;i<=NF;i++){if($i=="--ttl-set"){print $(i+1)}}}')
      ipv6_ttl=$(grep 'ip6tables -t mangle -A POSTROUTING' "$ttl_file" | awk '{for(i=1;i<=NF;i++){if($i=="--hl-set"){print $(i+1)}}}')
      echo -e "\e[32mCurrent IPv4 TTL: $ipv4_ttl\e[0m"
      echo -e "\e[32mCurrent IPv6 TTL: $ipv6_ttl\e[0m"
    fi

    echo -e "\e[32mWould you like to edit the TTL settings?\e[0m"
    echo -e "\e[32mTTL Value will be set without needing a reboot \e[0m"
    echo -e "\e[33mType yes or exit:\e[0m" && read -r response

    if [ "$response" = "exit" ]; then
      echo "Exiting..."
      break
    elif [ "$response" = "yes" ]; then
      echo -e "\e[32mType 0 to disable TTL\e[0m"
      echo -e "\e[33mEnter the TTL value (number only):\e[0m" && read -r ttl_value
      if ! [[ "$ttl_value" =~ ^[0-9]+$ ]]; then
        echo "Invalid input, please enter a number."
      else
        # Clear existing TTL rules
        echo "Clearing existing TTL rules..."
        iptables -t mangle -D POSTROUTING -o rmnet+ -j TTL --ttl-set "$ipv4_ttl"
        ip6tables -t mangle -D POSTROUTING -o rmnet+ -j HL --hl-set "$ipv6_ttl"

        if [ "$ttl_value" -eq 0 ]; then
          echo "Disabling TTL..."
          > "$ttl_file"
        else
          echo "Setting TTL to $ttl_value..."
          echo "iptables -t mangle -A POSTROUTING -o rmnet+ -j TTL --ttl-set $ttl_value" > "$ttl_file"
          echo "ip6tables -t mangle -A POSTROUTING -o rmnet+ -j HL --hl-set $ttl_value" >> "$ttl_file"
          iptables -t mangle -A POSTROUTING -o rmnet+ -j TTL --ttl-set $ttl_value
          ip6tables -t mangle -A POSTROUTING -o rmnet+ -j HL --hl-set $ttl_value
        fi
      fi
    fi
  done
}

mtu_setup() {
  local mtu_file="/etc/firewall.user.mtu"
  local lan_utils_script="/etc/data/lanUtils.sh"
  local combine_function="util_combine_iptable_rules"

  overlay_check || return

  while true; do
    # Ensure the MTU configuration file exists
    if [ ! -f "$mtu_file" ]; then
      echo "Creating $mtu_file..."
      touch "$mtu_file"

      echo "Modifying $combine_function in $lan_utils_script..."

      # Backup the original script
      cp "$lan_utils_script" "${lan_utils_script}.bak"

      # Add the local mtu_firewall_file line if it's not already present
      if ! grep -q "local mtu_firewall_file" "$lan_utils_script"; then
        sed -i '/local tcpmss_firewall_filev6/a \  local mtu_firewall_file=/etc/firewall.user.mtu' "$lan_utils_script"
      fi

      # Add the condition to include the mtu_firewall_file if it's not already present
      if ! grep -q "if \[ -f \"\$mtu_firewall_file\" \]; then" "$lan_utils_script"; then
        sed -i '/if \[ -f "\$ttl_firewall_file" \]; then/i \  if [ -f "\$mtu_firewall_file" ]; then\n    cat \$mtu_firewall_file >> \$firewall_file\n  fi' "$lan_utils_script"
      fi
    fi

    # Display the current MTU override, if set
    if [ ! -s "$mtu_file" ]; then
      echo -e "\e[31mMTU override is not set. Default MTU is applied at boot.\e[0m"
    else
      current_mtu=$(awk '/ip link set/ {print $6; exit}' "$mtu_file")
      echo -e "\e[32mCurrent MTU override: $current_mtu\e[0m"
    fi

    # Prompt user for actions
    echo -e "\e[32mWould you like to edit the MTU override?\e[0m"
    echo -e "\e[33mType a new MTU value, exit, or 0 to disable the override:\e[0m" && read -r response

    if [ "$response" = "exit" ]; then
      echo "Exiting..."
      break
    elif [ "$response" = "0" ]; then
      echo "Disabling MTU override and clearing the file..."
      > "$mtu_file"
    elif [[ "$response" =~ ^[0-9]+$ ]]; then
      echo "Setting MTU override to $response..."
      # Write single commands for each interface to the configuration file
      > "$mtu_file" # Clear the file
      for iface in $(ls /sys/class/net | grep '^rmnet_data'); do
        echo "ip link set $iface mtu $response" >> "$mtu_file"
      done
    else
      echo "Invalid input. Please enter a number, 'exit', or '0'."
    fi
  done
}




set_root_passwd() {
    passwd
}

# Function for Tailscale Submenu
tailscale_menu() {
    while true; do
        echo -e "\e[1;32mTailscale Menu\e[0m"
        echo -e "\e[1;32m1) Install/Update Tailscale\e[0m"
        echo -e "\e[1;36m2) Configure Tailscale\e[0m"
        echo -e "\e[1;31m3) Return to Main Menu\e[0m"
        read -p "Enter your choice: " tailscale_choice

        case $tailscale_choice in
            1) install_update_tailscale ;;
            2) configure_tailscale ;;
            3) break ;;
            *) echo "Invalid option" ;;
        esac
    done
}

# Function to install tailscale
install_update_tailscale() {
    overlay_check || return
    echo -e "\e[1;31mInstalling Tailscale 1.78.1...\e[0m"
    opkg update
    opkg install luci-app-tailscale
    
    echo -e "\e[1;32mTailscale version 1.78.1 installed\e[0m"
    echo -e "\e[1;32mNEW! Tailscale can be configured from Luci\e[0m"
}


# Function to Configure Tailscale
configure_tailscale() {
    while true; do
        echo "Configure Tailscale"
        echo -e "\e[38;5;27m1) Connect to Tailnet\e[0m"  # Brown
        echo -e "\e[38;5;87m2) Connect to Tailnet with SSH ON\e[0m"  # Light cyan
        echo -e "\e[38;5;105m3) Reconnect to Tailnet with SSH OFF\e[0m"  # Light magenta
        echo -e "\e[38;5;172m4) Disconnect from Tailnet (reconnects at reboot)\e[0m"  # Light yellow
        echo -e "\e[1;31m5) Logout from tailscale account\e[0m"
        echo -e "\e[38;5;27m6) Return to Tailscale Menu\e[0m"
        read -p "Enter your choice: " config_choice

        case $config_choice in
            1) tailscale up --accept-dns=false --reset ;;
            2) tailscale up --ssh --accept-dns=false --reset ;;
            3) tailscale up --accept-dns=false --reset ;;
            4) tailscale down ;;
            5) tailscale logout ;;
            6) break ;;
            *) echo "Invalid option" ;;
        esac
    done
}

# Main menu
while true; do
    echo "                           .%+:                              "
    echo "                             .*@@@-.                         "
    echo "                                  :@@@@-                     "
    echo "                                     @@@@#.                  "
    echo "                                      -@@@@#.                "
    echo "       :.                               %@@@@: -#            "
    echo "      .+-                                #@@@@%.+@-          "
    echo "      .#- .                               +@@@@# #@-         "
    echo "    -@*@*@%                                @@@@@::@@=        "
    echo ".+%@@@@@@@@@%=.                            =@@@@# #@@- ..    "
    echo "    .@@@@@:                                :@@@@@ =@@@..%=   "
    echo "    -::@-.+.                                @@@@@.=@@@- =@-  "
    echo "      .@-                                  .@@@@@:.@@@*  @@. "
    echo "      .%-                                  -@@@@@:=@@@@  @@# "
    echo "      .#-         .%@@@@@@#.               +@@@@@.#@@@@  @@@."
    echo "      .*-            .@@@@@@@@@@=.         @@@@@@ @@@@@  @@@:"
    echo "       :.             .%@@@@@@@@@@@%.     .@@@@@+:@@@@@  @@@-"
    echo "                        -@@@@@@@@@@@@@@@..@@@@@@.-@@@@@ .@@@-"
    echo "                         -@@@@@@@@@@%.  .@@@@@@. @@@@@+ =@@@="
    echo "                           =@@@@@@@@*  .@@@@@@. @@@@@@..@@@@-"
    echo "                            #@@@@@@@@-*@@@@@%..@@@@@@+ #@@@@-"
    echo "                            @@@@@@:.-@@@@@@.  @@@@@@= %@@@@@."
    echo "                           .@@@@. *@@@@@@- .+@@@@@@-.@@@@@@+ "
    echo "                           %@@. =@@@@@*.  +@@@@@@%.-@@@@@@%  "
    echo "                          .@@ .@@@@@=  :@@@@@@@@..@@@@@@@=   "
    echo "                          =@.+@@@@@. -@@@@@@@*.:@@@@@@@*.    "
    echo "                          %.*@@@@= .@@@@@@@-.:@@@@@@@+.      "
    echo "                          ..@@@@= .@@@@@@: #@@@@@@@:         "
    echo "                           .@@@@  +@@@@..%@@@@@+.            "
    echo "                           .@@@.  @@@@.:@@@@+.               "
    echo "                            @@@.  @@@. @@@*    .@.           "
    echo "                            :@@@  %@@..@@#.    *@            "
    echo "                         -*: .@@* :@@. @@.  -..@@            "
    echo "                       =@@@@@@.*@- :@%  @* =@:=@#            "
    echo "                      .@@@-+@@@@:%@..%- ...@%:@@:            "
    echo "                      .@@.  @@-%@:      .%@@*@@%.            "
    echo "                       :@@ :+   *@     *@@#*@@@.             "
    echo "                                     =@@@.@@@@               "
    echo "                                  .*@@@:=@@@@:               "
    echo "                                .@@@@:.@@@@@:                "
    echo "                              .@@@@#.-@@@@@.                 "
    echo "                             #@@@@: =@@@@@-                  "
    echo "                           .@@@@@..@@@@@@*                   "
    echo "                          -@@@@@. @@@@@@#.                   "
    echo "                         -@@@@@  @@@@@@%                     "
    echo "                         @@@@@. #@@@@@@.                     "
    echo "                        :@@@@# =@@@@@@%                      "
    echo "                        @@@@@: @@@@@@@:                      "
    echo "                        *@@@@  @@@@@@@.                      "
    echo "                        .@@@@  @@@@@@@                       "
    echo "                         #@@@. @@@@@@*                       "
    echo "                          @@@# @@@@@@@                       "
    echo "                           .@@+=@@@@@@.                      "
    echo "                                *@@@@@@                      "
    echo "                                 :@@@@@=                     "
    echo "                                  .@@@@@@.                   "
    echo "                                    :@@@@@*.                 "
    echo "                                      .=@@@@@-               "
    echo "                                           :+##+.            "

    echo -e "\e[92m"
    echo "Welcome to iamromulan's rcPCIe Toolkit script for Quectel RM55x Series modems!"
    echo "Visit https://github.com/iamromulan for more!"
    echo -e "\e[0m"
    echo -e "\e[91mThis is a test version of the toolkit for the new RM550/551 modems\e[0m" # Light Red
    echo "Select an option:"
    echo -e "\e[0m"
    echo -e "\e[96m1) Send AT Commands\e[0m" # Cyan
    echo -e "\e[92m2) Install sdxpinn-mount-fix/run me after a flash!\e[0m" # Green
    echo -e "\e[94m3) TTL Setup\e[0m" # Light Blue
    echo -e "\e[92m4) MTU Setup\e[0m" # Light Green	
    echo -e "\e[94m5) Install Basic Packages/enable luci/dropbear and add iamromulan's feed to opkg\e[0m" # Light Blue    
    echo -e "\e[94m6) Set root password\e[0m" # Light Blue
    echo -e "\e[94m7) Tailscale Management\e[0m" # Light Blue
    echo -e "\e[92m8) Install Speedtest.net CLI app (speedtest command)\e[0m" # Light Green
    echo -e "\e[93m9) Exit\e[0m" # Yellow (repeated color for exit option)
    read -p "Enter your choice: " choice

    case $choice in
        1) send_at_commands_using_atcmd ;;
        2) remount_rw; install_mount_fix ;;
        3) 
            overlay_check
            if [ $? -eq 1 ]; then continue; fi
            ttl_setup 
            ;;
		4)
            overlay_check
            if [ $? -eq 1 ]; then continue; fi
            mtu_setup 
            ;;		
        5)  
            overlay_check
            if [ $? -eq 1 ]; then continue; fi
            basic_55x_setup
            ;;       
            
        6) 
            overlay_check
            if [ $? -eq 1 ]; then continue; fi
            set_root_passwd 
            ;;
        7) tailscale_menu ;;
        8)
            overlay_check
            if [ $? -eq 1 ]; then continue; fi
            echo -e "\e[1;32mInstalling Speedtest.net CLI (speedtest command)\e[0m"
            cd /tmp
            curl -O https://raw.githubusercontent.com/$GITUSER/$GITREPO/$GITTREE/opkg-feed/ookla-speedtest_1.2.0_aarch64_cortex-a53.ipk
            opkg install ookla-speedtest_1.2.0_aarch64_cortex-a53.ipk            
            echo -e "\e[1;32mSpeedtest CLI (speedtest command) installed!!\e[0m"
            echo -e "\e[1;32mTry running the command 'speedtest'\e[0m"
            echo -e "\e[1;32mNote that it will not work unless you login to the root account first\e[0m"
            echo -e "\e[1;32mNormally only an issue in adb, ttyd, and ssh you are forced to login\e[0m"
            echo -e "\e[1;32mIf in adb just type login and then try to run the speedtest command\e[0m"
            ;;
        9) echo -e "\e[1;32mGoodbye!\e[0m"; break ;;
        *) echo -e "\e[1;31mInvalid option\e[0m" ;;
    esac
done
