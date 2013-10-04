#!/bin/bash

IMAGE_URL="http://downloads.openwrt.org/attitude_adjustment/12.09/atheros/generic"

IMAGE_FILE="openwrt-atheros-ubnt2-pico2-jffs2-64k.bin"
ETH=eth0

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "###########################################################"
echo "# WARNING WARNING WARNING WARNING WARNING WARNING WARNING #"
echo "#                                                         #"
echo "#        This script will temporarily disable your        #"
echo "#       networking and assumes that you are running       #"
echo "#      Ubuntu, that your system uses Network Manager      #"
echo "#      and that that your ethernet interface is eth0.     #"
echo "#         If either of these assumptions are wrong        #"
echo "#      this script may not work and your networking       #"
echo "#         may have to be brought back up manually.        #"
echo "#                                                         #"
echo "#       You should ensure that you are not connected      #"
echo "#       to any 192.168.1.x network before proceeding.     #"
echo "###########################################################"
echo " "
read -p "Proceed? [y/N]: " ANSWER

case $ANSWER in
    Y|y|Yes|yes|YES) echo "Proceeding.";;
    *) echo "Ok."; exit 1;;
esac


mkdir -p openwrt_image
cd openwrt_image

if [ -f $IMAGE_FILE ]; then
	echo "OpenWRT image file already downloaded."
else
	echo "Downloading OpenWRT image file."
	wget ${IMAGE_URL}/${IMAGE_FILE}
  if [ ! $? -eq 0 ]; then
      echo "Failed to download image file." 1>&2
      exit $?
  fi
fi



echo "###########################################################"
echo "#                                                         #"
echo "#         To get the router into its flashable mode       #"
echo "#  hold down the reset button (you need e.g. a paperclip) #"
echo "#               and power on the router.                  #"
echo "#    Let go of the reset button when the router begins    #"
echo "#        flashing its diodes between red and orange       #"
echo "#     (two of the green diodes will also be flashing)     #"
echo "#        Make sure the router's ethernet cable            #"
echo "#              is connected to this computer              #"
echo "#          The router is now ready to be flashed!         #"
echo "#                                                         #"
echo "###########################################################"
echo " "
read -p "Proceed? [y/N]: " ANSWER

case $ANSWER in
    Y|y|Yes|yes|YES) echo "Proceeding.";;
    *) echo "Ok."; exit 1;;
esac

echo "Temporarily reconfiguring networking for flashing"

service network-manager stop

if [ ! $? -eq 0 ]; then
    echo "Failed to stop network manager," 1>&2
    echo "or maybe your system doesn't use it?" 1>&2
    exit $?
fi

# we don't care too much if this fails
ifconfig wlan0 down 2> /dev/null

ifconfig $ETH 192.168.1.249 netmask 255.255.255.0 up

if [ ! $? -eq 0 ]; then
    service network-manager start
    echo "Failed to set IP address for ${ETH}." 1>&2
    exit $?
fi

echo "Flashing router!"

echo -e "binary\ntimeout 60\ntrace\nput ${IMAGE_FILE}" | tftp 192.168.1.20

if [ ! $? -eq 0 ]; then
    echo "Flashing failed." 1>&2
    ifconfig $ETH down
    service network-manager start
    exit $?
fi

echo "Flashing complete!"

case $ANSWER in
    Y|y|Yes|yes|YES) echo "Proceeding.";;
    *) echo "Ok."; exit 1;;
esac

echo "Restarting network-manager"



echo " "
echo "The router should now be copying the image to its internal flash memory."
echo "If this is working, the bottom two diodes should be on, and"
echo "the top four diodes should be flashing in sequence:"
echo "  1, 2, 3, 4, 3, 2, 1, etc."
echo " "
echo "Wait 5 to 7 minutes for the router to come back up."
echo "Then run the remote_install.sh script"
echo "You do not need to be root or use sudo for the remote_install.sh script"
echo " "

echo "Do you want to restore your network configuration state to the way"
echo "it was before running this script (start network manager)."
echo "or do you want to keep the network configuration as is so you"
echo "can connect to your newly flashed router?"
echo " "
read -p "Do you intend to connect to your router now? [Y/n]: " ANSWER
echo " "

case $ANSWER in
    n|N|No|no|NO) 
        echo "Ok. Restarting network-manager."
        ifconfig $ETH down
        service network-manager start
        echo "Done"
        ;;
    *)
        echo "Ok. You should now be able to connect"
        echo "to the router using the command: "
        echo " "
        echo "  telnet 192.168.1.1"
        echo " "
        echo "Make sure you run the passwd command after logging in"
        echo "to set a root password."
        echo " "
        echo "NOTE: After setting the root password you can no longer"
        echo "      log in using telnet, but will have to log in using:"
        echo " "
        echo "  ssh root@192.168.1.1"
        echo " "
        ;;
esac


cd ..

