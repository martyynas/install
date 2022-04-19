#! /bin/bash

# Update the system clock
timedatectl set-ntp true

# Formatting partitions
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mkswap /dev/sda3

# Mounting the partitions
mount /dev/sda2 /mnt
mkdir /mnt/efi
mount /dev/sda1 /mnt/efi
swapon /dev/sda3

# Installation
pacstrap /mnt base base-devel linux linux-firmware  networkmanager nano

# Chroot into the installtion
arch-chroot /mnt

# Setting the timezone
ln -sf /usr/share/zoneinfo/Europe/Vilnius /etc/localtime
hwclock --systohc --utc

# Localization
server=en_US.UTF-8; sed -i "/^#$server/ c$server" /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 >> /etc/locale.conf

# Network configuration
hostnamectl set-hostname linuxOS

# Root password
passwd

# Bootloader installtion
pacman -S intel-ucode
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Arch-Linux
grub-mkconfig -o /boot/grub/grub.cfg


# Installing yay
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -sirc
cd ..
rm -rf yay

