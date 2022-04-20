#! /bin/bash

# Setting the timezone
ln -sf /usr/share/zoneinfo/Europe/Vilnius /etc/localtime

# Localization
nano /etc/locale.gen
locale-gen
echo LANG=en_GB.UTF-8 > /etc/locale.conf
export LANG=en_GB.UTF-8

#Set your host name
echo linuxOS > /etc/hostname
touch /etc/hosts
nano /etc/hosts

# Root password
passwd

# Add user
useradd -m -G wheel martynas
passwd martynas
nano /etc/sudoers

# Network installtion
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager 

# Bootloader installtion
pacman -S --noconfirm intel-ucode
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Arch-Linux
grub-mkconfig -o /boot/grub/grub.cfg