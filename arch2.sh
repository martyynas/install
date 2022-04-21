#!/bin/bash

ln -sf /usr/share/zoneinfo/Europe/Vilnius /etc/localtime
hwclock --systohc
sed -i '178s/.//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "arch" >> /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 arch.localdomain arch" >> /etc/hosts
passwd

pacman -S --needed efibootmgr networkmanager  dosfstools linux-zen-headers gvfs ntfs-3g 

systemctl enable NetworkManager
systemctl enable fstrim.timer

useradd -m -G wheel martynas
passwd martynas

echo "martynas ALL=(ALL:ALL) ALL" >> /etc/sudoers

bootctl --path=/boot install