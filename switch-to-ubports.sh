#!/bin/sh

set -e

DEFAULT_CHANNEL="ubports-touch/15.04/rc"

cleanup()
{
  rm $tmp_channel || true
  rm $tmp_recovery || true
}

trap cleanup 0 1 2 3 15

check_req()
{
	if [ ! -x "$(which adb)" ] || [ ! -x "$(which fastboot)" ]; then
		echo "please install the android-tools-fastboot and android-tools-adb packages" && exit 1
	fi
}

flash_recovery()
{
  tmp_recovery=$(mktemp)
  if ! wget -q --show-progress "http://cdimage.ubports.com/devices/recovery-$device.img" -O $tmp_recovery; then
    echo "Could not download recovery to this device"
    exit 1
  fi
  if ! file $tmp_recovery | grep -q "Android bootimg"; then
    echo "something is wrong with the recoveyr file"
    exit 1
  fi
  recovery_part=$(curl -q "http://cdimage.ubports.com/devices/fstab/$device.fstab" | grep "/recovery" | cut -d " " -f 1)
  if ! adb shell "file $recovery_part" | grep -q "character special"; then
    echo "something is wrong with getting recovery partition"
    exit 1
  fi
  adb push $tmp_recovery $tmp_recovery > /dev/null 2>&1
  echo "flashing recovery at $recovery_part"
  read -p "pin/password for your device (needed for sudo to modify partition): " pass
  adb shell "echo $pass | sudo -S sh -c 'cat $tmp_recovery > $recovery_part'"
  adb shell "rm $tmp_recovery"
  echo "\nrecovery flashed"
}

get_channel_ini()
{
  tmp_channel=$(mktemp)
  adb pull /etc/system-image/channel.ini $tmp_channel > /dev/null 2>&1
  if grep -q "system-image.ubports.com" $tmp_channel; then
    echo "You are alredy using UBports images"
  fi
  device=$(grep "device:" $tmp_channel | cut -d " " -f 2)
}

check_adb_access()
{
  if ! adb shell "cat /etc/system-image/channel.ini" > /dev/null 2>&1 ; then
    echo "please make sure the device is attched via USB and that the deivce has 'Developer mode' enabled"
  fi

}

check_req
check_adb_access
get_channel_ini
echo "Your device: $device"
flash_recovery
ubuntu-device-flash --server=http://system-image.ubports.com touch --device=$device \
--channel=$DEFAULT_CHANNEL
