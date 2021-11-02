#!/bin/bash

ls -R /usr/share/kbd/keymaps
loadkeys es
cfdisk /dev/sda

mkfs.ext4 -L ROOT /dev/sda2
mkfs.ext4 -L HOME /dev/sda3
mkfs.ext4 -L BOOT /dev/sda4
mkswap -L SWAP /dev/sda1

swapon /dev/disk/by-label/SWAP
mount /dev/disk/by-label/ROOT /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount /dev/disk/by-label/HOME /mnt/home
mount /dev/disk/by-label/BOOT /mnt/boot

ping artixlinux.org

basestrap /mnt base base-devel openrc
basestrap /mnt linux linux-firmware

fstabgen -U /mnt >> /mnt/etc/fstab
artix-chroot /mnt

ln -sf /usr/share/Australia/Sydney/ /etc/localtime
hwclock --systohc

pacman -S neovim
nano /etc/locale.gen
 
locale-gen
#NOT DONE system wide locate

pacman -S grub os-prober efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

passwd
useradd -m user
passwd user

nano /etc/hostname

nano /etc/hosts
 127.0.0.1        localhost
 ::1              localhost
 127.0.1.1        myhostname.localdomain	myhostname

pacman -S dhcpcd

exit
unmount -R /mnt
reboot

#Run after reboot - Install Programs
#Enable multilib in the pacman config by uncommenting these two lines in pacman.conf:
#nvim /etc/pacman.conf

#[multilib]
#Include = /etc/pacman.d/mirrorlist

#Upgrade your system:
#sudo pacman -Syyu

#Show 32-bit packages in the multilib repository:
#pacman -Sl | grep -i lib32

pacman -S xorg xf87-input-wacom

pacman -S mesa lib32-mesa xf86-video-ati mesa-vdpau lib32-mesa-vdpau 

sudo pacman -S --needed base-devel
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si

pacman -S keepassxc pass element-desktop veracrypt qbittorrent git youtube-dl wget mpv stellarium tcc zig tutanota-desktop discord newsboat rsync gparted btop whois python xorg dhcpcd nodejs

paru -s librewolf tutanota-desktop lbry zls-git

mkdir $HOME/zls && cd $HOME/zls && curl -L https://github.com/zigtools/zls/releases/download/0.1.0/x86_64-linux.tar.xz | tar -xJ --strip-components=1 -C .
