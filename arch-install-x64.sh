#!/bin/bash

# Prompt the user to select the drive
read -p "Enter the drive for installation (e.g., /dev/sda): " DRIVE

# Prompt the user to enter username
read -p "Enter username for the new user: " USERNAME

# Prompt the user to enter password
read -sp "Enter password for the new user: " PASSWORD
echo

# Partition the selected drive
echo -e "d\n1\nd\n2\nd\n3\nw" | fdisk $DRIVE
echo -e "n\n\n\n+100M\nn\n\n\n+4G\nn\n\n\n\nw" | fdisk $DRIVE

# Format the partitions
mkfs.fat -F32 ${DRIVE}p1
mkswap ${DRIVE}p2
mkfs.ext4 ${DRIVE}p3

# Mount the partitions
mount ${DRIVE}p3 /mnt
mkdir -p /mnt/boot/efi
mount ${DRIVE}p1 /mnt/boot/efi
swapon ${DRIVE}p2

# Install packages
pacstrap /mnt base linux linux-firmware sof-firmware base-devel grub efibootmgr nano networkmanager git mesa nvidia ntp dhcpcd xorg i3 networkmanager network-manager-applet alacritty lightdm lightdm-gtk-greeter

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the installed system
arch-chroot /mnt <<EOF
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "Arch Linux" > /etc/hostname
echo "root:root" | chpasswd
grep -q '^%sudo' /etc/group || groupadd sudo
echo "%sudo   ALL=(ALL:ALL) ALL" >> /etc/sudoers
useradd -m -G sudo -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable ntpd.service
systemctl start ntpd.service
timedatectl set-ntp true
systemctl enable NetworkManager
systemctl enable dhcpcd
systemctl enable lightdm
EOF
