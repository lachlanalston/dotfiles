#!/bin/bash
set -e

DISK="/dev/nvme0n1"  # Replace with your actual disk, e.g., /dev/sda
HOSTNAME="voidlinux"
USERNAME="user"
PASSWORD="password"  # You can change this later

# Partitioning (UEFI + ext4 with fdisk)
echo "Partitioning $DISK..."
wipefs -a "$DISK"
parted "$DISK" mklabel gpt

# Create partitions with fdisk
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

# Wait for partitions to be recognized
sleep 2

mkfs.fat -F32 "${DISK}p1"
mkfs.ext4 -F "${DISK}p2"

# Mounting
mount "${DISK}p2" /mnt
mkdir -p /mnt/boot/efi
mount "${DISK}p1" /mnt/boot/efi

# Bootstrap base system
xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt base-system grub-x86_64-efi

# Configuration
echo "$HOSTNAME" > /mnt/etc/hostname

# fstab
genfstab -U /mnt > /mnt/etc/fstab

# Chroot and configure
cat << EOF | chroot /mnt /bin/bash
ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
hwclock --systohc
echo -e "$PASSWORD\n$PASSWORD" | passwd root

useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Enable sudo for wheel group
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/99_wheel

xbps-reconfigure -f glibc-locales

# Bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=void
grub-mkconfig -o /boot/grub/grub.cfg
EOF

echo "Installation complete. You can now reboot."
