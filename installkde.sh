#!/bin/bash
set -euo pipefail

# --- DISKLER ---
ROOT=/dev/nvme0n1p5
EFI=/dev/nvme0n1p6

# --- 0) Format (sıfır kurulum) ---
mkfs.ext4 $ROOT
mkfs.fat -F32 $EFI

# --- 1) Mount ---
mount $ROOT /mnt
mkdir -p /mnt/boot/efi
mount $EFI /mnt/boot/efi

# --- 2) Base + mesa + kde + network + utils ---
pacstrap /mnt \
  base linux linux-firmware \
  vim nano sudo \
  mesa mesa-utils vulkan-intel intel-media-driver libva-utils \
  xorg xorg-xinit \
  plasma-meta sddm \
  networkmanager \
  grub efibootmgr os-prober \
  firefox konsole dolphin \
  xdg-user-dirs

# --- 3) Fstab ---
genfstab -U /mnt >> /mnt/etc/fstab

# --- 4) Chroot & config ---
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "tr_TR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo "archlinux" > /etc/hostname

echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   archlinux.localdomain archlinux" >> /etc/hosts

systemctl enable NetworkManager
systemctl enable sddm

# --- users ---
echo "root:0509" | chpasswd
useradd -m -G wheel -s /bin/bash user
echo "user:0509" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# --- grub ---
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch

# Dual boot için os-prober aktif
sed -i 's/GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub || echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

EOF

echo "Kurulum tamamlandı! Reboot atabilirsin."
