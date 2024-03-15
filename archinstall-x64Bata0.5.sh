#!/bin/bash

# Exit immediately if any command fails
set -e

# Function to handle errors
handle_error() {
    echo "Error occurred in line $1"
    exit 1
}
trap 'handle_error $LINENO' ERR

# Prompt the user to select the drive
read -p "Enter the drive for installation (e.g., /dev/sda): " DRIVE

# Prompt the user to enter root password
read -p "Enter password for root user: " ROOT_PASSWORD
echo

# Prompt the user to enter username
read -p "Enter username for the new user: " USERNAME

# Prompt the user to enter password
read -p "Enter password for the new user: " PASSWORD
echo

# Prompt the user to enter hostname
read -p "Enter hostname for the system: " HOSTNAME

# Prompt the user to enter additional packages
read -p "Enter additional packages (space-separated): " PACKAGES

# Prompt the user to enter additional services
read -p "Enter additional services to enable (space-separated): " SERVICES

# Format the partitions
echo "Formatting partitions..."
mkfs.fat -F32 ${DRIVE}p1    # Format EFI partition as FAT32
mkswap ${DRIVE}p2           # Format swap partition
mkfs.ext4 ${DRIVE}p3        # Format root partition

# Mount the partitions
echo "Mounting partitions..."
mount ${DRIVE}p3 /mnt                # Mount root partition to /mnt
mkdir -p /mnt/boot/efi                # Create directory for EFI partition
mount ${DRIVE}p1 /mnt/boot/efi        # Mount EFI partition to /mnt/boot/efi
swapon ${DRIVE}p2                     # Activate swap partition

# Install packages
echo "Installing packages..."
pacstrap /mnt base linux linux-firmware base-devel efibootmgr grub $PACKAGES

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the installed system
echo "Chrooting into the installed system..."
arch-chroot /mnt <<EOF
# Inside chroot environment
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime  # Set timezone
hwclock --systohc                                           # Set hardware clock
sed -i '/#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen          # Uncomment en_US.UTF-8 in locale.gen
locale-gen                                                  # Generate locale
echo "LANG=en_US.UTF-8" > /etc/locale.conf                  # Set system locale
echo "$HOSTNAME" > /etc/hostname                            # Set hostname
echo "root:$ROOT_PASSWORD" | chpasswd                       # Set root password
getent group sudo || groupadd sudo                          # Check and add sudo group if missing
echo "%sudo   ALL=(ALL:ALL) ALL" >> /etc/sudoers            # Add sudoers configuration
useradd -mG sudo -s /bin/bash "$USERNAME"                   # Create user and add to sudo group
echo "$USERNAME:$PASSWORD" | chpasswd                       # Set user password
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub  # Install GRUB bootloader
grub-mkconfig -o /boot/grub/grub.cfg                        # Generate GRUB configuration

for service in $SERVICES; do
    systemctl enable "\$service"                            # Enable additional services
done

EOF
