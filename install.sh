#! /bin/bash
# If someone linked you to this script as a way to install Arch, don't.
# This script is not user friendly - a single mistake can format your drive.
# It's heavily personalized, so it is likely to do something you do not want.

# To use this, simply boot the latest Arch ISO and run
# wget https://gitlab.com/C0rn3j/Arch/raw/master/install.sh && chmod +x install.sh && ./install.sh
# My installs are kept up to date via Ansible - https://gitlab.com/C0rn3j/configs/tree/master/ansible

# This script used to be pure bash, if you're looking for the old version - https://gitlab.com/C0rn3j/arch/blob/703dae958dab40002bf7b9bb85970f0d00d57acd/install.sh

# Silence shellcheck warnings:
# Ignore word splitting of unquoted variables
# shellcheck disable=SC2086
# Ignore read mangling backwards slashes
# shellcheck disable=SC2162

# Strict mode - http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
Red='\033[0;31m'
Yellow='\033[0;33m'
Blue='\033[0;94m'
NoColor='\033[0m'

createLUKSroot() {
	# https://wiki.archlinux.org/index.php/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS
	# Format partition as LUKS
	cryptsetup luksFormat /dev/${ROOTpartition}
	echo -e "${Yellow}Enter password again as we need to mount the volume${NoColor}"
	cryptsetup open /dev/${ROOTpartition} cryptlvminstall
	# -ff to force creation of physical volume in case it's there from a previous install
	pvcreate -ff /dev/mapper/cryptlvminstall
	vgcreate ArchVolInstall /dev/mapper/cryptlvminstall
	lvcreate -l 100%FREE ArchVolInstall -n root
	mkfs.ext4 /dev/ArchVolInstall/root
	mount /dev/ArchVolInstall/root /mnt/archinstall
}

pacmanConf() {
	sed -i s/#Color/Color/g /etc/pacman.conf
	sed -i s/#ParallelDownloads/ParallelDownloads/g /etc/pacman.conf
	sed -i s/#VerbosePkgLists/VerbosePkgLists\\nILoveCandy/g /etc/pacman.conf
}

if [[ $(id -u) != "0" ]]; then
	echo -e "${Red}Script needs to be run under the root user${NoColor}"
	exit 1
fi

if [[ -e /var/lib/pacman/db.lck ]]; then
	echo -e "${Red}Pacman lockfile detected, make sure nothing is using pacman, exiting.${NoColor}"
	exit 1
fi
if [[ -z ${1-} ]]; then
	# Start NTP so we get correct time and script doesn't fuck up on TLS errors
	timedatectl set-ntp true

	# In case this script was launched from a very limited Arch env, install tools the script uses
	if ! command -v grep sed parted >/dev/null; then
		if ! pacman -Sy grep sed systemd-sysvcompat parted dosfstools --noconfirm --needed; then
			pacman -Syu grep sed systemd-sysvcompat parted dosfstools --noconfirm --needed
		fi
	fi
	# Make sure the archinstall mount folder exists
	mkdir -p /mnt/archinstall
	# If previous install failed to unmount the partitions, unmount them
	if mountpoint -q "/mnt/archinstall/boot"; then
		umount -l /mnt/archinstall/boot
	fi
	if mountpoint -q "/mnt/archinstall"; then
		umount -l /mnt/archinstall
	fi
	# More verbose lsblk in the live install
	alias lsblk='lsblk -o +fstype,label,uuid'
	clear; lsblk
	echo -e "${Yellow}Select the drive you want to install Arch Linux on e.g. \"sda\" or \"sdb\" without the quotes.${NoColor}"
	read drive; clear
	# Check if system is booted via BIOS or UEFI mode
	if [[ -d /sys/firmware/efi ]]; then
		IsUEFI="yes"
	else
		IsUEFI="no"
	fi
	if grep Intel /proc/cpuinfo; then
		IntelCPU="yes"
	else
		IntelCPU="no"
	fi
	clear
	if [[ ${IsUEFI} == "no" ]]; then
		echo -e "${Red}This computer is booted in BIOS mode. Unless your hardware is 2011 or older, this is incorrect and you should use UEFI-style boot, not Legacy/CSM/BIOS boot. Change this in UEFI setup menu.\nEncryption is not supported by this script on BIOS, it requires a separate /boot partition.\n${NoColor}"
		echo -e "${Yellow}Press ENTER to continue.${NoColor}"
		read; clear
	fi
	echo -e "${Yellow}How would you like to name this computer?${NoColor}"
	read hostname; clear
	echo -e "${Yellow}What password should root(administrator) account have?${NoColor}"
	read rootpassword; clear
	echo -e "${Yellow}What username do you want?\nLinux only allows lower case letters and numbers by default.\nIt is bad practice to use the root account for daily use, and some graphical programs will refuse to work under it or they'll be broken,\
so this user is the account you should normally use${NoColor}"
	read username; clear
	echo -e "${Yellow}What password should ${Blue}${username}${Yellow} have?${NoColor}"
	read userpassword; clear
	timezone=$(tzselect); clear
	echo -e "${Yellow}Do you want to encrypt the install? You will be required to enter a decrypt password each boot.\nThis setup uses LVM on LUKS. /boot partition remains unencrypted on UEFI installs.${NoColor}"
	select yn in "Yes" "No"; do
		case $yn in
			Yes ) answerEncrypt="yes"; break;;
			No ) answerEncrypt="no"; break;;
		esac
	done
	clear
	echo -e "${Yellow}Is this a graphical install? If you are unsure, select yes.\nThis script installs KDE Plasma.${NoColor}"
	select yn in "Yes" "No"; do
		case $yn in
			Yes ) answerDE="yes"; break;;
			No ) answerDE="no"; break;;
		esac
	done
	clear
	echo -e "${Yellow}Do you want to set up passwordless autologin for ${Blue}${username}${Yellow}?${NoColor}"
	select yn in "Yes" "No"; do
		case $yn in
			Yes ) answerGetty="yes"; break;;
			No ) answerGetty="no"; break;;
		esac
	done
	clear
	if lspci | grep NVIDIA >/dev/null; then
		echo -e "${Yellow}Nvidia GPU was detected, do you want to install latest Nvidia drivers?\nIf you are unsure, select yes. You may need older drivers if your card is very old.\n\
${Red}This script does NOT support intel+Nvidia hybrid setup.${NoColor}"
		select yn in "Yes" "No"; do
			case $yn in
				Yes ) answerNVIDIA="yes"; break;;
				No ) answerNVIDIA="no"; break;;
			esac
		done
		clear
	else
		answerNVIDIA="no"; # No Nvidia card detected, setting no to satisfy strict mode.
	fi
	if lspci | grep Radeon >/dev/null; then
		echo -e "${Yellow}Do you want to install the AMDGPU driver?\nSelect yes if unsure. This script does not support very old AMD GPUs.${NoColor}"
		select yn in "Yes" "No"; do
			case $yn in
				Yes ) answerAMD="yes"; break;;
				No ) answerAMD="no"; break;;
			esac
		done
		clear
	else
		answerAMD="no"; # No AMD card detected, setting no to satisfy strict mode.
	fi
	if [[ ${IntelCPU} == "yes" ]]; then # No point in asking with an AMD CPU
		echo -e "${Yellow}Do you want to install the xf86-video-intel driver? Select yes if this is a CPU with integrated GPU and is 3rd gen or older. The modesetting driver(default) is better for 4th gen and newer CPUs.${NoColor}"
		select yn in "Yes" "No"; do
			case $yn in
				Yes ) answerINTEL="yes"; break;;
				No ) answerINTEL="no"; break;;
			esac
		done
		clear
	else
		answerINTEL="no"; # No Intel CPU detected, setting no to satisfy strict mode.
	fi
	wipeWarning="If you choose not to do so, the drive ${Blue}${drive}${Red} will be wiped(drive, NOT partition!!) and used for this Arch installation. I repeat, if you select no your whole drive ${Blue}${drive}${Red} WILL BE WIPED!!"
	# Close previously open encrypted volumes in case we're rerunning an install
	if [[ ${answerEncrypt} == "yes" ]]; then
		if [[ -e "/dev/mapper/ArchVolInstall-root" ]]; then
			cryptsetup close /dev/mapper/ArchVolInstall-root
		fi
		# The crypted volume needs to be closed last
		if [[ -e "/dev/mapper/cryptlvminstall" ]]; then
			cryptsetup close /dev/mapper/cryptlvminstall
		fi
	fi
	# BIOS BLOCK
	if [[ ${IsUEFI} == "no" ]]; then
		ESPpartition="none" # So it doesn't end up missing on the declare line
		echo -e "${Yellow}Do you want to select an already existing root partition?\n${Red}${wipeWarning}${NoColor}"
		select yn in "Yes" "No"; do
			case $yn in
				Yes ) answer="yes"; break;;
				No ) answer="no"; break;;
			esac
		done
		clear
		if [[ ${answer} == "yes" ]]; then
			lsblk
			echo -e "${Yellow}Which partition should be used for root? e.g. \"sda2\" - ${Red}It will be formatted.${NoColor}"
			read ROOTpartition
			if [[ ${answerEncrypt} == "yes" ]]; then
				createLUKSroot
			else
				mkfs.ext4 /dev/${ROOTpartition}
				mount /dev/${ROOTpartition} /mnt/archinstall
			fi
		else
			wipefs -a /dev/${drive}
			parted -s /dev/${drive} mklabel msdos
			parted -s /dev/${drive} mkpart primary ext4 1MiB 100%
			parted -s /dev/${drive} set 1 boot on
			ROOTpartition="${drive}1"
			if [[ ${answerEncrypt} == "yes" ]]; then
				createLUKSroot
			else
				mkfs.ext4 /dev/${drive}1
				mount /dev/${drive}1 /mnt/archinstall
			fi
		fi
	fi
	# UEFI BLOCK
	if [[ ${IsUEFI} == "yes" ]]; then
		clear; echo -e "${Yellow}Do you want to select already existing partitions(ESP and root)?\n${Red}${wipeWarning}${NoColor}"
		select yn in "Yes" "No"; do
			case $yn in
				Yes ) answer="yes"; break;;
				No ) answer="no"; break;;
			esac
		done
		if [[ ${answer} == "yes" ]]; then
			lsblk
			echo -e "${Yellow}Which partition should be used for root? e.g. \"sda2\" - ${Red}It will be formatted.${NoColor}"
			read ROOTpartition; clear
			if [[ ${answerEncrypt} == "yes" ]]; then
				createLUKSroot
			else
				mkfs.ext4 /dev/${ROOTpartition}
				mount /dev/${ROOTpartition} /mnt/archinstall
			fi
			lsblk
			echo -e "${Yellow}Which EFI(ESP) partition should be used? e.g. \"sda1\"${NoColor}"
			read ESPpartition; clear
			mkdir -p /mnt/archinstall/boot
			# /mnt/archinstall/boot needs to be mounted AFTER /mnt/archinstall
			mount /dev/${ESPpartition} /mnt/archinstall/boot
			clear
		else # Wipe drive and create partitions anew
			# If the drive is NVMe the naming scheme differs from the usual naming
			if echo ${drive} | grep "nvme"; then
				Part1Name="p1"
				Part2Name="p2"
			else
				Part1Name="1"
				Part2Name="2"
			fi
			# Define root and ESP variables for bootloader and LUKS usage
			ESPpartition=${drive}${Part1Name}
			ROOTpartition=${drive}${Part2Name}
			wipefs -a /dev/${drive}
			parted -s /dev/${drive} mklabel gpt
			parted -s /dev/${drive} mkpart ESP fat32 1MiB 513MiB
			parted -s /dev/${drive} set 1 boot on
			parted -s /dev/${drive} mkpart primary ext4 513MiB 100%
			if [[ ${answerEncrypt} == "yes" ]]; then
				createLUKSroot
			else
				mkfs.ext4 /dev/${drive}${Part2Name}
				mount /dev/${drive}${Part2Name} /mnt/archinstall
			fi
			mkfs.fat -F32 /dev/${drive}${Part1Name}
			mkdir -p /mnt/archinstall/boot
			# /mnt/archinstall/boot needs to be mounted AFTER /mnt/archinstall
			mount /dev/${drive}${Part1Name} /mnt/archinstall/boot
		fi
	fi
	# Delete old vmlinuz file in case there is an install already from a previous time
	if [[ -e /mnt/archinstall/boot/vmlinuz-linux ]]; then
		rm -f /mnt/archinstall/boot/vmlinuz-linux
	fi
	# If this is the live ISO env, set max live space to 2GB instead of 256MB to be able to do a -Syu in the live env
	# Booting with kernel param cow_spacesize=2G does the same thing
	if mount | grep /run/archiso/cowspace >/dev/null; then
		mount -o remount,size=2G /run/archiso/cowspace
	fi

	# MAIN BLOCK
	# Make pacman output prettier in the live env
	pacmanConf
	# Install reflector in the live env to download and sort mirrorlist so the install doesn't hang on downloading packages
	# If it fails due to different dependencies on ISO vs current packages or running, just update the entire live boot env
	echo -e "${Yellow}Ranking mirrors for faster download speeds...${NoColor}"
	if ! command -v reflector >/dev/null; then
		if ! pacman -Sy reflector --noconfirm --needed; then
			pacman -Syu reflector --noconfirm --needed
		elif ! reflector -h >/dev/null; then
			pacman -Syu reflector --noconfirm --needed
		fi
	fi
	# Ranks lastest 15 mirrors only
	reflector --latest 15 --sort rate --save /etc/pacman.d/mirrorlist
	# Install base system
	pacstrap /mnt/archinstall ansible base base-devel linux linux-firmware wget git
	cp /etc/pacman.d/mirrorlist /mnt/archinstall/etc/pacman.d/mirrorlist
	genfstab -U /mnt/archinstall > /mnt/archinstall/etc/fstab
	cp ${BASH_SOURCE} /mnt/archinstall/root
	declare -p hostname rootpassword username userpassword timezone answerGetty IsUEFI drive answerEncrypt answerDE ESPpartition ROOTpartition answerAMD answerNVIDIA answerINTEL IntelCPU > /mnt/archinstall/root/answerfile
	echo -e "${Yellow}Running keyring population to avoid broken keyring on a clean pacstrap${NoColor}" # https://t.me/archlinuxgroup/507931
	arch-chroot /mnt/archinstall /usr/bin/pacman-key --populate archlinux
	arch-chroot /mnt/archinstall /bin/bash -c "/root/$(basename ${BASH_SOURCE}) letsgo" # letsgo is there only to make the script know to run the secondary part by having ${1} defined, it can be any string.
else # We're in chroot. ${1} is only set after chrooting
	git clone --depth 1 https://gitlab.com/C0rn3j/configs.git /root/configs
	ansible-galaxy collection install -r /root/configs/ansible/playbooks/requirements.yaml
	ansible-galaxy role install -r /root/configs/ansible/playbooks/requirements.yaml
	ansible-playbook /root/configs/ansible/playbooks/site.yaml
	# Source answers
	source /root/answerfile
	# The default keymap is already 'us' but sd-vconsole hook requires this file to exist.
	echo "KEYMAP=us" > /etc/vconsole.conf
	# Check if mkinitcpio.conf has the correct HOOKS string
	defaultHooks="HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)"
	# Encrypt hooks
	encryptHooks="HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt lvm2 filesystems fsck)"

	if ! grep "${defaultHooks}" /etc/mkinitcpio.conf; then
		echo -e "${Red}Default hook config in /etc/mkinitcpio.conf changed, fix the script!${NoColor}"
		exit 1
	fi
	if [[ ${answerEncrypt} == "yes" ]]; then
		# Replace the default hooks with the ones needed for encryption and regenerate initramfs
		sed -i s/"${defaultHooks}"/"${encryptHooks}"/ /etc/mkinitcpio.conf
		mkinitcpio -p linux
	fi
	# Use NetworkManager as a network manager
	systemctl enable NetworkManager
	# Install CPU microcode based on which CPU was detected.
	# --overwrite in case ucode was previously already installed
	if [[ ${IntelCPU} == "yes" ]]; then
		pacman -Syu intel-ucode --noconfirm --overwrite='/boot/intel-ucode.img'
	else
		pacman -Syu amd-ucode --noconfirm --overwrite='/boot/amd-ucode.img'
	fi
	clear
	hwclock --systohc --utc
	echo ${hostname} > /etc/hostname
	echo "root:${rootpassword}" | chpasswd
	echo "${username}:${userpassword}" | chpasswd

	# UEFI BLOCK
	if [[ ${IsUEFI} == "yes" ]]; then
		# Cleanup useless dump files in case they exist, they could prevent bootloader setup
		rm -f /sys/firmware/efi/efivars/dump-*
		# Install systemd-boot to the ESP
		# Using graceful flag to allow installation on buggy UEFIs - https://github.com/systemd/systemd/issues/13603#issuecomment-864860578
		bootctl install --graceful
		echo "default arch" > /boot/loader/loader.conf
		echo "timeout 1" >> /boot/loader/loader.conf
		echo "editor 1" >> /boot/loader/loader.conf
		echo "title Arch Linux" > /boot/loader/entries/arch.conf
		echo "linux /vmlinuz-linux" >> /boot/loader/entries/arch.conf
		if [[ ${IntelCPU} == "yes" ]]; then
			echo "initrd /intel-ucode.img" >> /boot/loader/entries/arch.conf
		else
			echo "initrd /amd-ucode.img" >> /boot/loader/entries/arch.conf
		fi
		echo "initrd /initramfs-linux.img" >> /boot/loader/entries/arch.conf
		if [[ ${answerEncrypt} == "yes" ]]; then
		# Disable password timeouts https://wiki.archlinux.org/index.php/Dm-crypt/System_configuration#Timeout
			echo "options rd.luks.options=timeout=0 rootflags=x-systemd.device-timeout=0 rd.luks.name=$(blkid -s UUID -o value /dev/${ROOTpartition})=cryptlvm root=/dev/ArchVolInstall/root rw" >> /boot/loader/entries/arch.conf
		else
			echo "options root=PARTUUID=$(blkid -s PARTUUID -o value /dev/${ROOTpartition}) rw" >> /boot/loader/entries/arch.conf
		fi
	fi

	# BIOS BLOCK
	if [[ ${IsUEFI} == "no" ]]; then
		pacman -Syu grub os-prober --noconfirm
		defaultCmdline="GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\""
		# Disable password timeouts https://wiki.archlinux.org/index.php/Dm-crypt/System_configuration#Timeout
		encryptCmdline="GRUB_CMDLINE_LINUX_DEFAULT=\"rd.luks.options=timeout=0 rootflags=x-systemd.device-timeout=0 rd.luks.name=$(blkid -s UUID -o value \/dev\/${ROOTpartition})=cryptlvm root=\/dev\/ArchVolInstall\/root\""
		if ! grep "${defaultCmdline}" /etc/default/grub; then
			echo -e "${Red}Default cmdline config in /etc/default/grub changed, fix the script!${NoColor}"
			exit 1
		fi
		if [[ ${answerEncrypt} == "yes" ]]; then
			# Replace the default cmdline with one needed for encryption
			sed -i s/"${defaultCmdline}"/"${encryptCmdline}"/ /etc/default/grub
		fi
		grub-install --target=i386-pc /dev/${drive}
		grub-mkconfig -o /boot/grub/grub.cfg
	fi

	if [[ ${answerGetty} == "yes" ]]; then
		if [[ ${answerDE} == "yes" ]]; then
			# Autologin into Plasma
			cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=${username}
Session=plasma.desktop
EOF
		else
			# Headless install - enable autologin on tty1
			mkdir -p /etc/systemd/system/getty@tty1.service.d
			echo "[Service]" > /etc/systemd/system/getty@tty1.service.d/override.conf
			echo "ExecStart=" >> /etc/systemd/system/getty@tty1.service.d/override.conf
			echo "ExecStart=-/usr/bin/agetty --autologin ${username} -s %I 115200,38400,9600 vt102" >> /etc/systemd/system/getty@tty1.service.d/override.conf
		fi
	fi
	chown ${username}:${username} -R /home/${username}
	exit
fi
clear
echo -e "${Yellow}Looks like the first part of the installation was a success! Now you should reboot with 'reboot'.${NoColor}"
echo -e "${Yellow}After you login, run corn-postinstall from a terminal after the reboot to finish the installation.${NoColor}"
