#!/bin/bash

# Prompt the user to select the drive
read -p "Enter the drive for installation (e.g., /dev/sda): " DRIVE

# Partition the selected drive
echo -e "o\nn\np\n1\n\n+100M\na\nn\np\n2\n\n+4G\nn\np\n3\n\n\nw" | fdisk $DRIVE

# Format the partitions
mkfs.ext2 ${DRIVE}1
mkswap ${DRIVE}2
mkfs.ext4 ${DRIVE}3

# Mount the partitions
mount ${DRIVE}3 /mnt
mkdir -p /mnt/boot
mount ${DRIVE}1 /mnt/boot
swapon ${DRIVE}2

# Install base system
pacstrap /mnt base linux linux-firmware base-devel grub nano networkmanager git mesa nvidia ntp dhcpcd xorg i3 networkmanager network-manager-applet alacritty lightdm lightdm-gtk-greeter 

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
useradd -m -G sudo -s /bin/bash archuser
echo "archuser:archuser" | chpasswd
grub-install --target=i386-pc $DRIVE
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable ntpd.service
systemctl start ntpd.service
timedatectl set-ntp true
systemctl enable NetworkManager
systemctl enable dhcpcd
systemctl enable lightdm
EOF
