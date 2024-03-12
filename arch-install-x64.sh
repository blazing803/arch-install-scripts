#!/bin/bash

# Prompt the user to select the drive
read -p "Enter the drive for installation (e.g., /dev/sda): " DRIVE

# Prompt the user to enter root password
read -sp "Enter password for root user: " ROOT_PASSWORD
echo

# Prompt the user to enter username
read -p "Enter username for the new user: " USERNAME

# Prompt the user to enter password
read -sp "Enter password for the new user: " PASSWORD
echo

# Prompt the user to enter additional packages
read -p "Enter additional packages (space-separated): " PACKAGES

# Prompt the user to enter additional services
read -p "Enter additional services to enable (space-separated): " SERVICES

# Partition the selected drive
echo -e "o\nn\n\n\n+100M\nn\n\n\n+4G\nn\n\n\n\nw" | fdisk "$DRIVE"

# Format the partitions
mkfs.fat -F32 "${DRIVE}1"
mkswap "${DRIVE}2"
mkfs.ext4 "${DRIVE}3"

# Mount the partitions
mount "${DRIVE}3" /mnt
mkdir -p /mnt/boot/efi
mount "${DRIVE}1" /mnt/boot/efi
swapon "${DRIVE}2"

# Install packages
pacstrap /mnt base linux linux-firmware base-devel efibootmgr grub $PACKAGES

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the installed system
arch-chroot /mnt <<EOF
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
sed -i '/#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "Arch Linux" > /etc/hostname
echo "root:$ROOT_PASSWORD" | chpasswd
getent group sudo || groupadd sudo
echo "%sudo   ALL=(ALL:ALL) ALL" >> /etc/sudoers
useradd -mG sudo -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

for service in $SERVICES; do
    systemctl enable "\$service"
done

EOF