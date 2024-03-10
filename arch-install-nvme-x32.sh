#!/bin/bash
echo -e "d\n1\nd\n2\nd\n3\nw" | fdisk /dev/nvme0n1
echo -e "n\n\n\n+100M\nn\n\n\n+4G\nn\n\n\n\nw" | fdisk /dev/nvme0n1
mkfs.fat -F32 /dev/nvme0n1p1
mkswap /dev/nvme0n1p2
mkfs.ext4 /dev/nvme0n1p3
mount /dev/nvme0n1p3 /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
swapon /dev/nvme0n1p2
pacstrap /mnt base linux linux-firmware sof-firmware base-devel grub efibootmgr nano networkmanager git mesa nvidia ntp dhcpcd xorg i3 networkmanager network-manager-applet alacritty lightdm lightdm-gtk-greeter
genfstab -U /mnt >> /mnt/etc/fstab
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
grub-install --target=i386-pc /dev/nvme0n1
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable ntpd.service
systemctl start ntpd.service
timedatectl set-ntp true
systemctl enable NetworkManager
systemctl enable dhcpcd
systemctl enable lightdm
EOF
