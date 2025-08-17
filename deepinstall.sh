#!/bin/bash
# ---- Dell G15 5530 Arch Linux Full Rice Setup ----

# Kullanıcı bilgisi (kurulum sonrası değiştirmeyi unutma)
USER_NAME="user"
USER_PASS="password"
ROOT_PASS="password"

# Bölümleri formatla
mkfs.ext4 /dev/nvme0n1p5
mkfs.fat -F32 /dev/nvme0n1p6

# Mount
mount /dev/nvme0n1p5 /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p6 /mnt/boot

# Multilib ve temel paketler
echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
pacman -Sy --noconfirm

# Temel sistem ve paketler
pacstrap /mnt base linux linux-firmware intel-ucode \
nvidia-open-dkms linux-headers lib32-nvidia-utils \
pipewire pipewire-alsa pipewire-pulse lib32-pipewire wireplumber \
bluez bluez-utils bluez-obex \
networkmanager \
sddm hyprland waybar rofi foot playerctl \
xdg-desktop-portal-hyprland hyprpolkitagent tlp tlp-rdw \
git curl jq

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot
arch-chroot /mnt /bin/bash <<EOF

# Locale & Saat
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

# Hostname
echo "arch-g15" > /etc/hostname
echo -e "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\tarch-g15.localdomain arch-g15" > /etc/hosts

# Root ve kullanıcı
echo "root:$ROOT_PASS" | chpasswd
useradd -m -G wheel,network -s /bin/bash $USER_NAME
echo "$USER_NAME:$USER_PASS" | chpasswd
echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER_NAME

# Systemd-boot
bootctl --path=/boot install
root_uuid=\$(blkid -s PARTUUID -o value /dev/nvme0n1p5)
cat <<EOL > /boot/loader/loader.conf
default arch
timeout 4
editor 0
EOL

cat <<EOL > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=PARTUUID=\$root_uuid rw nvidia-drm.modeset=1
EOL

# NVIDIA
echo "options nvidia-drm modeset=1" > /etc/modprobe.d/nvidia.conf
mkinitcpio -P

# Servisler
systemctl enable --now NetworkManager
systemctl enable --now bluetooth
systemctl enable --now sddm
systemctl enable --now tlp
systemctl mask systemd-rfkill

# Hyprland Config
mkdir -p /home/$USER_NAME/.config/hypr
cat <<EOL > /home/$USER_NAME/.config/hypr/hyprland.conf
monitor = eDP-1, 1920x1080@60, 0x0, 1, decoration_corner_radius=10
monitor = HDMI-A-1, 2560x1080@60, 1920x0, 1, decoration_corner_radius=10

general {
    border_size = 2
    gap_size = 6
    animation = true
}
windowrulev2 = float, class:rofi
EOL

# Waybar Config & Theme
mkdir -p /home/$USER_NAME/.config/waybar
cat <<EOL > /home/$USER_NAME/.config/waybar/config
{
  "layer": "top",
  "position": "top",
  "modules-left": ["sway/workspaces", "network", "battery", "clock"],
  "modules-right": ["pulseaudio", "custom/music", "bluetooth", "backlight"],
  "custom/music": {
      "exec": "playerctl metadata --format '{{ artist }} - {{ title }}'",
      "interval": 5
  }
}
EOL

cat <<EOL > /home/$USER_NAME/.config/waybar/style.css
* {
  border-radius: 10px;
  background-color: rgba(30,30,30,0.7);
  color: #D9E0EE;
}
EOL

# Rofi Config
mkdir -p /home/$USER_NAME/.config/rofi
cat <<EOL > /home/$USER_NAME/.config/rofi/config.rasi
configuration {
  modi: "drun,run,ssh,window";
  show-icons: true;
}
window {
  background-color: rgba(30,30,30,230);
  border-radius: 12px;
}
listview {
  fixed-height: 2;
}
element {
  padding: 6px;
}
EOL

# Rofi sözlük komutu
echo 'alias dict="curl -s https://api.dictionaryapi.dev/api/v2/entries/en/"' >> /home/$USER_NAME/.bashrc

# Sahiplik
chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/.config

EOF

echo "Kurulum tamamlandı! Sistemi reboot et ve SDDM üzerinden Hyprland oturumuna gir."
