
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
mkdir /mnt/efi
mount /dev/sda1 /mnt/efi
swapon /dev/sda2

# Installation
pacstrap /mnt base base-devel linux-zen linux-firmware nano networkmanager

# hostname
echo "linux" > /mnt/etc/hostname

# localtime
ln -sf /mnt/usr/share/zoneinfo/Europe/Vilnius /mnt/etc/localtime

# Root password
arch-chroot /mnt /root
passwd root

# Genfstab
genfstab -U -p /mnt > /mnt/etc/fstab

# boot-systemd
arch-chroot /mnt /root
bootctl --path=/boot install

# enable NetworkManager
arch-chroot /mnt /root
systemctl enable NetworkManager






