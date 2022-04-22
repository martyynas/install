
#!/bin/bash

# Update the system clock
timedatectl set-ntp true

# Partition the drive
cfdisk /dev/sda

# Format the Partitions
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2

# Mounting the partitions
mount /dev/sda2 /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot

# Select an appropriate mirror
pacman -Syy
pacman -S reflector
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector  -c "US" -f 12 -l 10 -n 12 --download-timeout 60  --save /etc/pacman.d/mirrorlist

# Install Arch Linux
pacstrap /mnt base base-devel linux-zen linux-firmware nano git intel-ucode

# Generate the fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Systemd-Boot
arch-chroot /mnt bootctl install
cat <<EOF > /mnt/boot/loader/loader.conf
default arch
EOF
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title    Arch Linux
linux    /vmlinuz-linux-zen
initrd   /intel-ucode.img
initrd   /initramfs-linux-zen.img
options  root=PARTUUID=$(blkid -s PARTUUID -o value "$part_root") rw
EOF

# Chroot into the installtion
arch-chroot /mnt



