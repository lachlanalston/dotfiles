#!/bin/bash
set -euo pipefail

### === CONFIGURATION ===
DISK="/dev/sdX"             # ⚠️ Change this
CRYPT_NAME="cryptroot"
MOUNTPOINT="/mnt/void"
HOSTNAME="void"
USERNAME="user"
PASSWORD="password"
TIMEZONE="Australia/Sydney"
LOCALE="en_US.UTF-8"
BOOTLOADER_ID="VOID"

### === PARTITIONING ===
echo "[+] Wiping and partitioning $DISK"
sgdisk -Z "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System Partition" "$DISK"
sgdisk -n 2:0:0     -t 2:8300 -c 2:"Linux LUKS" "$DISK"

EFI_PART="${DISK}1"
CRYPT_PART="${DISK}2"

### === FORMAT AND ENCRYPT ===
echo "[+] Formatting EFI partition"
mkfs.vfat -F32 "$EFI_PART"

echo "[+] Setting up LUKS on $CRYPT_PART"
cryptsetup luksFormat --type luks2 "$CRYPT_PART"
cryptsetup open "$CRYPT_PART" "$CRYPT_NAME"

echo "[+] Creating Btrfs filesystem"
mkfs.btrfs -f /dev/mapper/"$CRYPT_NAME"

### === BTRFS SUBVOLUMES ===
echo "[+] Mounting and creating subvolumes"
mount /dev/mapper/"$CRYPT_NAME" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@snapshots
umount /mnt

### === MOUNT LAYOUT ===
echo "[+] Mounting subvolumes"
mount -o noatime,compress=zstd,subvol=@ /dev/mapper/"$CRYPT_NAME" "$MOUNTPOINT"

mkdir -p "$MOUNTPOINT"/{boot/efi,home,var/log,var/cache/xbps,.snapshots}

mount -o noatime,compress=zstd,subvol=@home       /dev/mapper/"$CRYPT_NAME" "$MOUNTPOINT/home"
mount -o noatime,compress=zstd,subvol=@log        /dev/mapper/"$CRYPT_NAME" "$MOUNTPOINT/var/log"
mount -o noatime,compress=zstd,subvol=@cache      /dev/mapper/"$CRYPT_NAME" "$MOUNTPOINT/var/cache/xbps"
mount -o noatime,compress=zstd,subvol=@snapshots  /dev/mapper/"$CRYPT_NAME" "$MOUNTPOINT/.snapshots"

mount "$EFI_PART" "$MOUNTPOINT/boot/efi"

### === INSTALL BASE SYSTEM ===
echo "[+] Installing base system"
xbps-install -Sy -R https://repo-default.voidlinux.org/current -r "$MOUNTPOINT" base-system grub btrfs-progs cryptsetup lvm2 sudo dracut-network

### === BASIC CONFIG ===
echo "[+] Configuring system"

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

echo 'KEYMAP=us' > /etc/vconsole.conf

echo "[+] Setting up crypttab and fstab"
echo "$CRYPT_NAME UUID=$(blkid -s UUID -o value $CRYPT_PART) none luks,discard" > /etc/crypttab
UUID_ROOT=$(blkid -s UUID -o value /dev/mapper/$CRYPT_NAME)
cat > /etc/fstab <<FSTAB
UUID=$UUID_ROOT  /              btrfs  rw,noatime,compress=zstd,subvol=@          0 1
UUID=$UUID_ROOT  /home          btrfs  rw,noatime,compress=zstd,subvol=@home      0 2
UUID=$UUID_ROOT  /var/log       btrfs  rw,noatime,compress=zstd,subvol=@log       0 2
UUID=$UUID_ROOT  /var/cache/xbps btrfs rw,noatime,compress=zstd,subvol=@cache     0 2
UUID=$UUID_ROOT  /.snapshots    btrfs  rw,noatime,compress=zstd,subvol=@snapshots 0 2
UUID=$(blkid -s UUID -o value $EFI_PART) /boot/efi vfat defaults 0 1
FSTAB

echo "[+] Installing GRUB and regenerating initrd"
xbps-reconfigure -fa
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=$BOOTLOADER_ID
grub-mkconfig -o /boot/grub/grub.cfg

EOF

### === CLEANUP ===
echo "[+] Cleaning up mounts"
umount -R "$MOUNTPOINT"
cryptsetup close "$CRYPT_NAME"

echo "[✓] Done! You can now reboot into your new Void Linux system."
