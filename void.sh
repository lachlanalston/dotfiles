#!/bin/bash
set -e

DISK="/dev/nvme0n1"  # Replace with your actual disk, e.g., /dev/sda
HOSTNAME="voidlinux"
USERNAME="user"
PASSWORD="password"  # You can change this later

# Partitioning (UEFI + ext4)
echo "Partitioning $DISK..."
sgdisk -Z "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" "$DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux Root" "$DISK"

mkfs.fat -F32 "${DISK}1"
mkfs.ext4 -F "${DISK}2"

# Mounting
mount "${DISK}2" /mnt
mkdir -p /mnt/boot/efi
mount "${DISK}1" /mnt/boot/efi

# Bootstrap base system
xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt base-system grub-x86_64-efi

# Configuration
echo "$HOSTNAME" > /mnt/etc/hostname

# fstab
genfstab -U /mnt > /mnt/etc/fstab

# Chroot and configure
cat << 'EOF' | chroot /mnt /bin/bash
ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
hwclock --systohc
passwd root <<PASS
$PASSWORD
$PASSWORD
PASS

useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Enable sudo for wheel group
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/99_wheel

xbps-reconfigure -f glibc-locales

# Bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=void
grub-mkconfig -o /boot/grub/grub.cfg
EOF

# Done
echo "Installation complete. You can now reboot."
