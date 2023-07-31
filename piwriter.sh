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
echo "Preparing to write $SRC on $TARGET, which currently looks like this:"
echo ""
diskutil list $TARGET
echo ""
echo "Double check that the size of partition 0 matches expectations"
echo "then press return to proceed, control-C to abort..."

read foo

diskutil unmountdisk $TARGET

echo "This will take a bit.  Starting at \c"
date

time dd if="$SRC" of=$TARGET bs=128k

# 8 seconds wasn't enough for Ubuntu (worked for Raspbian).
# 10 works for Ubuntu on Mojave.
sleep 12

# /Volumes/boot implies Raspbian (buster or earlier)
if [ -d /Volumes/boot ]
then
  echo "mmmm, this is probably older Raspbian..."
  BOOTDIR="/Volumes/boot"
fi

# /Volumes/system-boot implies Ubuntu
if [ -d /Volumes/system-boot ]
then
  echo "This smells like Ubuntu to me..."
  BOOTDIR="/Volumes/system-boot"
fi

if [ -d /Volumes/bootfs ]
then
  echo "I smell your bullseye..."
  BOOTDIR="/Volumes/bootfs"
fi


if [ -n "$BOOTDIR" ]
then
  echo "Touching $BOOTDIR/ssh"
  touch "$BOOTDIR"/ssh
  echo "Setting up pi/raspberry for login (you have been warned!!!)"
# pi:raspberry
  echo 'pi:$6$1gQEEtJelY2.1RlF$bKtefSfqeA5/qHoLVhVNi1lPMoqr/K46gSHplB/MIXf9cSma1FAMfTs4RRHSKsb5idIJvdMmW4l4aMBHjkcML/' > "$BOOTDIR"/userconf.txt
else
  echo "Apparently not Raspbian or Ubuntu; skipping enabling ssh"
fi

if [ -f "./wpa_supplicant.conf" -a -n "$SSID" ]
then
  echo "You specified an SSID on the command line but you have a ./wpa_supplicant.conf"
  echo "I'm confused, giving up!"
  exit 1
fi

if [ -f "./wpa_supplicant.conf" ]
then
  cp ./wpa_supplicant.conf "$BOOTDIR"/wpa_supplicant.conf
fi

# synthesize /Volumes/boot/wpa_supplicant.conf the Raspbian way...
if [ -n "$SSID" -a "$BOOTDIR" = "/Volumes/boot" ]
then
(
  echo "country=US"
  echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev"
  echo "update_config=1"
  echo ""
  echo "network={"
) > /Volumes/boot/wpa_supplicant.conf

  if [ -n "$PASSWORD" ]
  then
    echo " ssid=\"$SSID\"\n psk=\"$PASSWORD\"" >> /Volumes/boot/wpa_supplicant.conf
  else
    echo " ssid=\"$SSID\"\n key_mgmt=NONE" >> /Volumes/boot/wpa_supplicant.conf
  fi

  echo "}" >> /Volumes/boot/wpa_supplicant.conf

fi

# the Ubuntu way
if [ -n "$SSID" -a "$BOOTDIR" = "/Volumes/system-boot" ]
then
  echo "Writing the wifi information for ubuntu"
  if [ -z "$PASSWORD" ]
  then
      cat >> /Volumes/system-boot/network-config <<END
wifis:
  wlan0:
    dhcp4: true
    optional: true
    access-points:
      $SSID:

END
  else
      cat >> /Volumes/system-boot/network-config <<END
wifis:
  wlan0:
    dhcp4: true
    optional: true
    access-points:
      $SSID:
        password: "$PASSWORD"

END
  fi

fi

sync

diskutil unmountdisk $TARGET

echo "done at \c"
date

exit 0

