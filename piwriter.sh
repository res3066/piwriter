#!/bin/sh

usage()
{
  echo "Usage: $0 [ -s ssid [ -p password ] ] [ -t /dev/rtargetdisk ] -f image.img"
  exit 2
}

WHOAMI=`whoami`
if [ "$WHOAMI" != "root" ] ; then
  echo "do you even sudo?"
  exit 1
fi

PASSWORD=""
TARGET=""

while getopts 's:p:f:t:' c
do
  case $c in
    s) SSID=$OPTARG ;;
    p) PASSWORD=$OPTARG ;;
    f) SRC=$OPTARG ;;
    t) TARGET=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$SRC" ]
then
  usage
fi

if [ -z "$TARGET" ]
then
  TARGET=`diskutil list | awk '$2 == "(external," && $3 == "physical):" { print $1 }'`
fi

if [ -z "$TARGET" ]
then
  echo "couldn't auto-identify a target, try being specific with -t /dev/rtargetdisk"
  exit 1
fi

#SRC=$1

echo ""
echo "Currently writing $SRC on $TARGET, which currently looks like this:"
echo ""
diskutil list $TARGET
echo ""
echo "Double check that the size of partition 0 matches expectations"
echo "then press return to proceed, control-C to abort..."

read foo

diskutil unmountdisk $TARGET

echo "This will take a bit.  Starting at \c"
date

time dd if=$SRC of=$TARGET bs=256k

sleep 8

if [ -d /Volumes/boot ]
then
  echo "Touching /boot/ssh"
  touch /Volumes/boot/ssh
else
  echo "Apparently not Raspbian, skipping /boot/ssh"
fi

if [ -n "$SSID" ]
then
echo "country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={" > /Volumes/boot/wpa_supplicant.conf

if [ -n "$PASSWORD" ]
then
echo " ssid=\"$SSID\"\n psk=\"$PASSWORD\"" >> /Volumes/boot/wpa_supplicant.conf
else
echo " ssid=\"$SSID\"\n key_mgmt=NONE" >> /Volumes/boot/wpa_supplicant.conf
fi

echo "}" >> /Volumes/boot/wpa_supplicant.conf

fi

sync

diskutil unmountdisk $TARGET

echo "done at \c"
date

exit 0

