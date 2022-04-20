
#!/bin/bash

# Update the system clock
timedatectl set-ntp true

# Disk
cfdisk /dev/sda

# Formatting partitions
mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2
mkfs.ext4 /dev/sda3

# Mounting the partitions
mount /dev/sda3 /mnt
swapon /dev/sda2

# Installation
pacstrap /mnt base base-devel linux-zen linux-firmware nano networkmanager git

# Installation genfstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the installtion
arch-chroot /mnt