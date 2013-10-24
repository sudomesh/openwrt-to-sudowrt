#!/bin/bash

IP="192.168.1.1"

if [ "$1" = "-h" ]; then
    echo " " 1>&2
    echo "Usage: ${0} [router_ip]" 1>&2
    echo " " 1>&2
    echo "  If not specified, router_ip defaults to 192.168.1.1" 1>&2
    echo " " 1>&2
    exit 0
fi

if [ $# -eq "1" ]; then
    IP=$1
fi
echo " "
echo "Preparing to configure the server at ${IP}"
echo " "
read -p "Is this what you want? [y/N]: " ANSWER

case $ANSWER in
    Y|y|Yes|yes|YES) 
        echo "Ok."
        ;;
    *) 
        echo "Ok. Goodbye."
        exit 1
        ;;
esac




PDIR=packages.untracked
PDIR_EXTRA=packages

# URL from which to install packages
URL="http://downloads.openwrt.org/attitude_adjustment/12.09/atheros/generic/packages"

# Packages to fetch and install
IPKS=("ip_3.3.0-1_atheros.ipk" "kmod-batman-adv_3.3.8+2012.3.0-3_atheros.ipk" "kmod-lib-crc16_3.3.8-1_atheros.ipk" "kmod-l2tp_3.3.8-1_atheros.ipk" "kmod-l2tp-eth_3.3.8-1_atheros.ipk" "kmod-l2tp-ip_3.3.8-1_atheros.ipk" "libpthread_0.9.33.2-1_atheros.ipk" "librt_0.9.33.2-1_atheros.ipk" "nano_2.2.6-1_atheros.ipk" "libncurses_5.7-5_atheros.ipk" "terminfo_5.7-5_atheros.ipk" "libopenssl_1.0.1e-1_atheros.ipk" "zlib_1.2.7-1_atheros.ipk")

# list of directories or files in current directory that need to
# be copied to the node after packages are installed
CONF_FILES="etc opt" 

echo "########################################################"
echo "# Before you run this script, please flash your router #"
echo "# with OpenWRT Attitude Adjustment, then log into the  #"
echo "# router with telnet and set a root password.          #"
echo "########################################################"
echo " "
read -p "Have you already done so? [y/N]: " ANSWER

case $ANSWER in
    Y|y|Yes|yes|YES) echo "Proceeding.";;
    *) echo "Ok."; exit 1;;
esac

echo "###########################################################"
echo "# WARNING WARNING WARNING WARNING WARNING WARNING WARNING #"
echo "#                                                         #"
echo "#              The node configuration files               #"
echo "#                  will be overwritten!                   #"
echo "###########################################################"
echo " "
read -p "Proceed? [y/N]: " ANSWER

case $ANSWER in
    Y|y|Yes|yes|YES) echo "Proceeding.";;
    *) echo "Ok."; exit 1;;
esac

mkdir -p $PDIR
cd $PDIR

echo "Downloading required packages"

for ((i = 0; i < ${#IPKS[@]}; i++)); do
    IPK=${IPKS[$i]}

    if [ -f $IPK ]; then
        echo "${IPK} already downloaded. Skipping."
    else
        echo "Downloading ${IPK}"
        wget "${URL}/${IPK}"

        if [ ! $? -eq 0 ]; then
            echo "Failed to download package ${IPK}" 1>&2
            exit $?
        fi
    fi
done

echo "All packages downloaded"
cd ..

echo " "
echo "------------------------------------------------------------------"
echo "This is a good time to ensure that you are connected to the router"
echo "using ethernet, that this computer's ethernet adapter  has an IP"
echo "on the same subnet as ${IP} and that any other network adapters,"
echo "like your wifi adapter, do _not_ have any IPs on the same subnet"
echo "as ${IP}."
echo "You can probably do that with the commands: "
echo "  sudo service network-manager stop"
echo "  sudo ifconfig wlan0 down"
echo "  sudo ifconfig eth0 192.168.1.249 subnet 255.255.255.0 up"
echo "but make sure to change the IP and subnet in that last command"
echo "if ${IP} is not in the 192.168.1.x range."
echo " "
read -p "Press any key to continue"

echo " "
echo "Granting key-based ssh access to node"

PUBKEY=~/.ssh/id_rsa.pub

if [ ! -f $PUBKEY ]; then
    PUBKEY=~/.ssh/id_dsa.pub

    if [ ! -f $PUBKEY ]; then
        echo "Could not find your ssh public key." 1>&2
        echo "You should probably run: ssh-keygen -t rsa" 1>&2
        exit 1
    fi
fi    

echo "Please wait. In a moment you may be asked for the node's root password."


AUTHKEY_PATH=/etc/dropbear/authorized_keys
cat $PUBKEY | ssh root@${IP} "cat >> ${AUTHKEY_PATH}; chmod 0600 ${AUTHKEY_PATH}"

if [ ! $? -eq 0 ]; then
    echo "Failed to set up key-based ssh access" 1>&2
    exit $?
fi

echo " "
echo "Copying packages to router"
scp -r $PDIR root@${IP}:/tmp/

if [ ! $? -eq 0 ]; then
    echo "Secure copy of packages failed" 1>&2
    exit $?
fi

scp -r $PDIR_EXTRA/*.ipk root@${IP}:/tmp/${PDIR}

if [ ! $? -eq 0 ]; then
    echo "Secure copy of extra packages failed" 1>&2
    exit $?
fi

echo " "
echo "Installing packages"

ssh root@${IP} "opkg install /tmp/${PDIR}/*.ipk"

if [ ! $? -eq 0 ]; then
    echo "Failed to install packages" 1>&2
    exit $?
fi

echo " "
echo "Cleaning up packages"
ssh root@${IP} "rm -rf /tmp/${PDIR}"

if [ ! $? -eq 0 ]; then
    echo "Failed to clean up packages" 1>&2
    exit $?
fi

echo " "
echo "Copying configuration files"

scp -r $CONF_FILES root@${IP}:/

if [ ! $? -eq 0 ]; then
    echo "Failed to copy configuration files" 1>&2
    exit $?
fi

echo " "
echo "Disabling autostart of tunneldigger and built-in firewall"
ssh root@${IP} "rm /etc/rc.d/S90tunneldigger" 2> /dev/null
ssh root@${IP} "rm /etc/rc.d/S45firewall" 2> /dev/null

echo " "
echo "Installation complete!"
echo " "
echo "You need to reboot your node to get the new configuration working,"
echo "but first plug your routers ethernet cable into a router/switch"
echo "that has an internet connection, or at least a DHCP server."
echo "Reboot the router by unpluggin and re-plugging the PoE adapter."
echo " "
echo "Available SSIDs after the node boots will be:"
echo "  peoplesopen.net"
echo "    This is the open, non-password-protected, SSID"
echo "    For ssh access: ssh root@10.42.0.1"
echo "    ssh password is: sudoer"
echo "  peoplesprivate"
echo "    This is the private, password-protected SSID."
echo "    Wifi password is: sudoersudoer"
echo "    For ssh access: ssh root@172.30.0.1"
echo "    ssh password is: sudoer"
echo "  peoplesopen.net-backchannel"
echo "    This is only used by the node to talk to other mesh routers."
echo " "



