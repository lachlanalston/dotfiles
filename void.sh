#!/bin/bash
set -e

DISK="/dev/nvme0n1"  # Change this if needed, e.g., /dev/sda
HOSTNAME="voidlinux"
USERNAME="user"
PASSWORD="password"  # You can change this later

# Partitioning
echo "Partitioning $DISK..."
wipefs -a "$DISK"

fdisk "$DISK" <<EOF
g
n
1

+1G
t
1
n
2


w
EOF

# Identify partition names
if [[ "$DISK" == *"nvme"* ]]; then
  EFI="${DISK}p1"
  ROOT="${DISK}p2"
else
  EFI="${DISK}1"
  ROOT="${DISK}2"
fi

# Format partitions
mkfs.fat -F32 "$EFI"
mkfs.ext4 -F "$ROOT"

# Mount
mount "$ROOT" /mnt
mkdir -p /mnt/boot/efi
mount "$EFI" /mnt/boot/efi

# Bootstrap base system with automatic key acceptance
xbps-install -Sy -y -R https://repo-default.voidlinux.org/current -r /mnt base-system grub-x86_64-efi

# Configuration
echo "$HOSTNAME" > /mnt/etc/hostname

# Generate /etc/fstab manually
EFI_UUID=$(blkid -s UUID -o value "$EFI")
ROOT_UUID=$(blkid -s UUID -o value "$ROOT")

cat <<EOF > /mnt/etc/fstab
# /etc/fstab: static file system information.
# <file system> <mount point> <type> <options> <dump> <pass>
UUID=$ROOT_UUID / ext4 defaults 0 1
UUID=$EFI_UUID /boot/efi vfat umask=0077 0 2
EOF

# Chroot system configuration
cat <<EOF | chroot /mnt /bin/bash
ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
hwclock --systohc
echo -e "$PASSWORD\n$PASSWORD" | passwd root

useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/99_wheel
xbps-reconfigure -f glibc-locales

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=void
grub-mkconfig -o /boot/grub/grub.cfg
EOF

echo "Installation complete. You can now reboot."
