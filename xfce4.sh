
#!/bin/bash

# Update
sudo pacman –Syu --noconfirm

# Install xfce4
sudo pacman -S --noconfirm xfce4 xfce4-goodies sddm pulseaudio pavucontrol firefox

# sddm service 
sudo systemctl enable sddm

# Reboot
sudo reboot --noconfirm