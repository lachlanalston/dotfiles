#!/bin/bash
set -euo pipefail

# === CONFIGURATION ===
DISK="/dev/vda"                 # <--- CHANGE THIS
CRYPT_NAME="cryptroot"
MOUNTPOINT="/mnt/void"
HOSTNAME="voidlinux"
USERNAME="user"
PASSWORD="password"
TIMEZONE="Australia/Sydney"
LOCALE="en_US.UTF-8"
BOOTLOADER_ID="VOID"

# === WIPE AND PARTITION ===
echo "[+] Wiping and partitioning $DISK using fdisk"
wipefs -a "$DISK"

fdisk "$DISK" <<EOF
g
n
1

+512M
t
1
n
2


w
EOF

EFI_PART="${DISK}1"
CRYPT_PART="${DISK}2"

# === FORMAT AND ENCRYPT ===
echo "[+] Formatting EFI partition..."
mkfs.vfat -F32 "$EFI_PART"

echo "[+] Encrypting $CRYPT_PART with LUKS2..."
cryptsetup luksFormat --type luks2 "$CRYPT_PART"
cryptsetup open "$CRYPT_PART" "$CRYPT_NAME"

# === CREATE BTRFS AND SUBVOLUMES ===
echo "[+] Creating Btrfs filesystem and subvolumes..."
mkfs.btrfs -f /dev/mapper/"$CRYPT_NAME"
mount /dev/mapper/"$CRYPT_NAME" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@snapshots

umount /mnt

# === MOUNT BTRFS SUBVOLUMES ===
echo "[+] Mounting Btrfs subvolumes..."
mount -o noatime,compress=zstd,subvol=@ /dev/mapper/"$CRYPT_NAME" "$MOUNTPOINT"

mkdir -p "$MOUNTPOINT"/{boot/efi,home,var/log,var/cache/xbps,.snapshots}

mount -o noatime,compress=zstd,subvol=@home       /dev/mapper/"$CRYPT_NAME" "$MOUNTPOINT/home"
mount -o noatime,compress=zstd,subvol=@log        /dev/mapper/"$CRYPT_NAME" "$MOUNTPOINT/var/log"
mount -o noatime,compress=zstd,subvol=@cache      /dev/mapper/"$CRYPT_NAME" "$MOUNTPOINT/var/cache/xbps"
mount -o noatime,compress=zstd,subvol=@snapshots  /dev/mapper/"$CRYPT_NAME" "$MOUNTPOINT/.snapshots"

mount "$EFI_PART" "$MOUNTPOINT/boot/efi"

# === INSTALL BASE SYSTEM ===
echo "[+] Installing base system..."
xbps-install -Sy -R https://repo-default.voidlinux.org/current -r "$MOUNTPOINT" base-system grub-x86_64-efi cryptsetup lvm2 btrfs-progs dracut-network sudo

# === CONFIGURE SYSTEM ===
echo "[+] Setting up system configuration..."
cp /etc/resolv.conf "$MOUNTPOINT/etc/"

mount --rbind /sys "$MOUNTPOINT/sys"
mount --rbind /proc "$MOUNTPOINT/proc"
mount --rbind /dev "$MOUNTPOINT/dev"

chroot "$MOUNTPOINT" /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
echo "LANG=$LOCALE" > /etc/locale.conf
echo "$LOCALE UTF-8" > /etc/default/libc-locales
xbps-reconfigure -f glibc-locales

useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd

echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

echo "[+] Configuring crypttab and fstab..."
UUID_CRYPT=$(blkid -s UUID -o value "$CRYPT_PART")
UUID_EFI=$(blkid -s UUID -o value "$EFI_PART")
UUID_ROOT=$(blkid -s UUID -o value /dev/mapper/$CRYPT_NAME)

echo "$CRYPT_NAME UUID=$UUID_CRYPT none luks,discard" > /etc/crypttab

cat > /etc/fstab <<FSTAB
UUID=$UUID_ROOT / btrfs rw,noatime,compress=zstd,subvol=@ 0 1
UUID=$UUID_ROOT /home btrfs rw,noatime,compress=zstd,subvol=@home 0 2
UUID=$UUID_ROOT /var/log btrfs rw,noatime,compress=zstd,subvol=@log 0 2
UUID=$UUID_ROOT /var/cache/xbps btrfs rw,noatime,compress=zstd,subvol=@cache 0 2
UUID=$UUID_ROOT /.snapshots btrfs rw,noatime,compress=zstd,subvol=@snapshots 0 2
UUID=$UUID_EFI /boot/efi vfat defaults 0 1
FSTAB

echo "[+] Regenerating initramfs and installing GRUB..."
xbps-reconfigure -fa
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=$BOOTLOADER_ID
grub-mkconfig -o /boot/grub/grub.cfg
EOF

# === CLEANUP ===
echo "[+] Cleaning up..."
umount -R "$MOUNTPOINT"
cryptsetup close "$CRYPT_NAME"

echo "[✓] Done. Reboot and remove installation media."
