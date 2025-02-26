#!/bin/bash
. /etc/ashrc

tempdir=`mktemp -d 2>/dev/null`
disk=$1
buggybios=$2

mounted()
{
        if [ "`cat /proc/mounts |grep -e $1 -c`" -ne "0" ]; then
                return 0
        else
                return 1
        fi
}

un_mount()
{
        for i in `mount |grep -e $disk |cut -d " " -f3`; do
                while mounted $i; do
			sync
                        umount -f $i
			sleep 1
                done
        done
        swapoff -a
        sleep 1
}

do_mounts()
{
	sleep 1
	while ! mounted /boot ; do
		mount -t vfat /dev/${disk}1 /boot
		sleep 1
	done
	while ! mounted /tmp-root ; do
		mount -t ext4 /dev/${disk}2 /tmp-root
		sleep 1
	done
	while ! mounted /thinstation ; do
		mount -t ext4 /dev/${disk}4 /thinstation
		sleep 1
	done
}

read_pt()
{
	sync
	blockdev --rereadpt $disk
	sleep 1
}

echo "Starting Partioner"
touch /tmp/nomount
un_mount
dd if=/dev/zero of=$disk bs=1M count=2
read_pt
parted -s $disk mklabel msdos
parted -s $disk mkpart primary fat32 "2048s 4196351s" 1>/dev/null
parted -s $disk set 1 boot on
parted -s $disk mkpart primary ext4 "4196352s 8390655s"
parted -s $disk mkpart primary linux-swap "8390656s 12584959s"
parted -s $disk mkpart primary ext4 "12584960s -0"
read_pt
un_mount
dd if=/install/mbr.bin of=$disk bs=440b count=1

echo "Making filesystems"
mkdosfs -n boot -F 32 -R 32 ${disk}1
sleep 1
#progress "Made boot Filesystem" 30
mkfs.ext4 ${disk}2
sleep 1
#progress "Made home Filesystem" 35
mkfs.ext4 ${disk}4
sleep 1
#progress "Made Dev Filesystem" 40
mkswap -L swap ${disk}3
sleep 1
#progress "Made swap Fileystem" 45
read_pt
un_mount
e2label ${disk}2 home
e2label ${disk}4 tsdev
sleep 1
#progress 50


echo "Remounting"
rm /tmp/nomount
read_pt
do_mounts
sleep 1

# Syslinux the boot partition
cd /boot
cp /install/* .
./syslinux -s ${disk}1
./syslinux ${disk}1

# Setup proxy for wget and git
proxy-setup
. /tmp/.proxy

# Install a default boot and backup-boot image into the boot partition
if [ -e /mnt/cdrom0/thindev-default.tar.xz ]; then
	tar -xvf /mnt/cdrom0/thindev-default.tar.xz
else
	echo "Downloading a Default Image"
	wget "$WEBUPDATEROOT/thindev-default.tar.xz"
	tar -xvf thindev-default.tar.xz
	rm thindev-default.tar.xz
fi

cp /boot/initrd /boot/initrd-backup
cp /boot/vmlinuz /boot/vmlinuz-backup
cp /boot/lib.update /boot/lib.squash-backup
cd /thinstation
rm -rf *

echo "Gitting thinstation repo"

git clone --depth 1 https://github.com/Thinstation/thinstation.git -b 5.2-Stable /thinstation

./setup-chroot -i
