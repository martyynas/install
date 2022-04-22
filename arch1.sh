#!/bin/bash

# Partition the disk
cfdisk /dev/sdb

# Format the partitions
mkfs.fat -F32 /dev/sdb1
mkfs.ext4 /dev/sdb2
#mkswap /dev/sda3

# Mount the partitions
mount /dev/sdb2 /mnt
mkdir /mnt/boot
mount /dev/sdb1 /mnt/boot
#swapon /dev/sda3

# Install the base packages
pacstrap /mnt base base-devel linux-zen linux-firmware git nano intel-ucode
 
# Generate the FSTAB
genfstab -U /mnt >> /mnt/etc/fstab
cat  /mnt/etc/fstab

# Chroot
arch-chroot /mnt
