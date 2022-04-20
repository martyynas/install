#! /bin/bash

# Setting the timezone
ln -sf /usr/share/zoneinfo/Europe/Vilnius /etc/localtime
hwclock --systohc --utc

# Localization
server=en_US.UTF-8; sed -i "/^#$server/ c$server" /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 >> /etc/locale.conf

#Set your host name
echo "${hostname}" > /mnt/etc/hostname

# Create a user and set roots password
arch-chroot /mnt useradd -mU -s /usr/bin/zsh -G wheel,uucp,video,audio,storage,games,input "$user"
arch-chroot /mnt chsh -s /usr/bin/zsh

echo "$user:$password" | chpasswd --root /mnt
echo "root:$password" | chpasswd --root /mnt

# Network installtion
pacman -S networkmanager
systemctl enable NetworkManager 

# Bootloader installtion
pacman -S intel-ucode
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Arch-Linux
grub-mkconfig -o /boot/grub/grub.cfg