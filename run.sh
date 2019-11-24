#!/bin/bash
#I DONT KNWO TO MAKE AUTO PARTITION

#EVERYTHING ELSE
mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2
swapon /dev/sda2
mkfs.ext4 /dev/sda3

mount /dev/sda3 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot


#Install
pacstrap /mnt base base-devel linux linux-firmware

#Configutation
genfstab -U /mnt >> /mnt/etc/fstab 
arch-chroot /mnt
ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
hwclock --systohc
locale-gen
echo "LANG=en_AU.UTF-8" > /etc/locale.conf
echo "t440p" > /etc/hostname
echo "127.0.0.1        localhost" >> /etc/hosts
echo "::1              localhost" >> /etc/hosts
echo "127.0.1.1        t440p.localdomain	t440p" >> /etc/hosts
passwd #Set Root Password

#User Groups
user add -m monarch
passwd monarch
pacman -S sudo
usermod -aG wheel,audio,video,optical,storage monarch

#Boot Loader
pacman -S grub efibootmgr xf86-video-intel mesa xorg-server i3-gaps xorg-server xorg-init dhcpcd networkmanager lxqt
yay -S displaylink
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
