#!/bin/bash

# Function to display error messages
error() {
    echo "Error: $1" >&2
    exit 1
}

# Function to check if a package is installed
package_installed() {
    pacman -Q "$1" &>/dev/null
}

# Function to install packages if not already installed
install_package() {
    if ! package_installed "$1"; then
        pacman -S --noconfirm "$1" || error "Failed to install package $1"
    fi
}

# Function to enable services
enable_service() {
    systemctl enable "$1" || error "Failed to enable service $1"
}

# Main script starts here

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root"
fi

# Prompt the user to select the drive
read -rp "Enter the drive for installation (e.g., /dev/sda): " DRIVE

# Validate drive input
if [ ! -b "$DRIVE" ]; then
    error "Invalid drive $DRIVE"
fi

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

# Prompt the user to enter swap size
read -p "Enter swap size in GB (0 for no swap): " SWAP_SIZE

# Prompt the user to enter additional packages
read -p "Enter additional packages (space-separated): " PACKAGES

# Prompt the user to enter additional services
read -p "Enter additional services to enable (space-separated): " SERVICES

# Create partitions using fdisk
fdisk "$DRIVE" <<EOF || error "Failed to create partitions using fdisk"
o # Create a new empty DOS partition table
n # Add a new partition
p # Primary partition
1 # Partition number 1
2048 # First sector
+512M # Last sector (512MB BIOS boot partition)
t # Set partition type
82 # Linux swap
n # Add a new partition
p # Primary partition
2 # Partition number 2 (root partition, using the rest of the disk)
w # Write changes
EOF

# Format the partitions
mkswap "${DRIVE}p1" || error "Failed to format swap partition ${DRIVE}p1"
mkfs.ext4 "${DRIVE}p2" || error "Failed to format root partition ${DRIVE}p2"

# Mount the root partition
mount "${DRIVE}p2" /mnt || error "Failed to mount root partition ${DRIVE}2"

# Activate swap
swapon "${DRIVE}p1" || error "Failed to activate swap partition ${DRIVE}1"

# Install base packages
pacstrap /mnt base linux linux-firmware base-devel grub $PACKAGES || error "Failed to install base packages"

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab || error "Failed to generate fstab"

# Chroot into the installed system
arch-chroot /mnt bash <<EOF || error "Failed to chroot into installed system"
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
sed -i '/#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname
echo "root:$ROOT_PASSWORD" | chpasswd
getent group sudo || groupadd sudo
echo "%sudo   ALL=(ALL:ALL) ALL" >> /etc/sudoers
useradd -mG sudo -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
grub-install --target=i386-pc "$DRIVE" || error "Failed to install GRUB bootloader"
grub-mkconfig -o /boot/grub/grub.cfg || error "Failed to generate GRUB configuration"


for service in $SERVICES; do
    systemctl enable "\$service"
done

echo "Installation completed successfully."

EOF

