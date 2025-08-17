#!/bin/bash
# 1. Bölümleri bağlama
mount /dev/nvme0n1p5 /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p6 /mnt/boot

# 2. Temel sistemi yükleme
pacstrap /mnt base linux linux-firmware intel-ucode \
    nvidia-open-dkms linux-headers lib32-nvidia-utils \
    pipewire pipewire-alsa pipewire-pulse lib32-pipewire wireplumber \
    bluez bluez-utils bluez-obex \
    networkmanager \
    sddm hyprland waybar rofi foot \
    xdg-desktop-portal-hyprland hyprpolkitagent \
    playerctl

# 3. fstab
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
# 4. Locale, Klavye, Saat
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

# 5. root şifresi (gereksiz ise atlayabilirsiniz)
echo "root:password" | chpasswd

# 6. Kullanıcı oluşturma
useradd -m -G wheel,network -s /bin/bash user
echo "user:password" | chpasswd
echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user

# 7. systemd-boot kurulumu
bootctl --path=/boot install
root_uuid=$(blkid -s PARTUUID -o value /dev/nvme0n1p5)
cat <<EOL > /boot/loader/loader.conf
default arch
EOL
cat <<EOL > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=PARTUUID=$root_uuid rw
EOL

# 8. NVIDIA ayarları
echo "options nvidia-drm modeset=1" > /etc/modprobe.d/nvidia.conf
mkinitcpio -P

# 9. SDDM ve NM servisi
systemctl enable --now NetworkManager
systemctl enable --now bluetooth
systemctl enable --now sddm

# 10. TLP etkinleştirme
systemctl enable --now tlp
systemctl mask systemd-rfkill

# 11. Waybar ve Rofi yapılandırmaları
mkdir -p /home/user/.config/waybar
cat <<EOL > /home/user/.config/waybar/config
{
    "layer": "top",
    "position": "top",
    "modules-left": ["sway/workspaces", "network", "battery", "clock"],
    "modules-right": ["pulseaudio", "custom/music"],
    "custom/music": {
        "exec": "playerctl metadata --format '{{ artist }} - {{ title }}'",
        "interval": 5
    }
}
EOL

mkdir -p /home/user/.config/rofi
cat <<EOL > /home/user/.config/rofi/config.rasi
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
EOL

# 12. Hyprland monitör konfigürasyonu
mkdir -p /home/user/.config/hypr
cat <<EOL > /home/user/.config/hypr/hyprland.conf
monitor = eDP-1, 1920x1080@60, 0x0, 1
monitor = HDMI-A-1, 2560x1080@60, 1920x0, 1
general {
    # Kodlama amaçlı şık ayarlar
    border_size = 2
    gap_size = 6
    decoration_corner_radius = 10
}
EOL

# Yetki ve sahiplik ayarları
chown -R user:user /home/user/.config

EOF
