#!/usr/bin/env bash
set -e

# === USER CONFIG ===
DISK_ROOT="/dev/nvme0n1p5"
DISK_EFI="/dev/nvme0n1p6"
HOSTNAME="archg15"
USERNAME="elon"
PASSWORD="1234"   # kurulum sonrası chpasswd ile değiştir
TIMEZONE="Europe/Istanbul"
KEYMAP="us"

# === FORMAT PARTITIONS ===
echo "[*] Formatting partitions..."
mkfs.ext4 $DISK_ROOT
mkfs.fat -F32 $DISK_EFI

# === MOUNT PARTITIONS ===
echo "[*] Mounting partitions..."
mount $DISK_ROOT /mnt
mkdir -p /mnt/boot
mount $DISK_EFI /mnt/boot

# === BASE SYSTEM INSTALL ===
echo "[*] Installing base system..."
pacstrap -K /mnt base linux linux-firmware sof-firmware \
    nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings egl-wayland \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber lib32-pipewire \
    bluez bluez-utils networkmanager \
    mesa vulkan-icd-loader lib32-vulkan-icd-loader \
    vim sudo git unzip wget curl base-devel sdcv

# === FSTAB ===
echo "[*] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# === CHROOT CONFIGURATION ===
arch-chroot /mnt /bin/bash <<EOF
echo "[*] Setting timezone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "[*] Locale..."
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "[*] Hostname..."
echo "$HOSTNAME" > /etc/hostname

echo "[*] Network setup..."
systemctl enable NetworkManager
systemctl enable bluetooth

echo "[*] Users..."
echo "root:$PASSWORD" | chpasswd
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/99_wheel

echo "[*] Bootloader..."
pacman -S --noconfirm grub efibootmgr os-prober
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1 nvidia.NVreg_EnableGpuFirmware=0 /' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "[*] Installing Hyprland + Rice..."
pacman -S --noconfirm hyprland xdg-desktop-portal-hyprland \
    waybar rofi kitty alacritty mako \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji \
    thunar gvfs thunar-archive-plugin file-roller brightnessctl pavucontrol playerctl \
    otf-font-awesome

# Create config directories
mkdir -p /home/$USERNAME/.config/{hypr,waybar,rofi,kitty,rofi/scripts}
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config

# === Hyprland config ===
cat <<HYPR >/home/$USERNAME/.config/hypr/hyprland.conf
monitor=,preferred,auto,1
monitor=HDMI-A-1,2560x1080@60,1920x0,1
exec-once = waybar & mako & nm-applet & blueman-applet
exec-once = hyprctl setcursor Bibata-Modern-Ice 24
general {
    gaps_in=8
    gaps_out=16
    border_size=3
    col.active_border=0xff82aaff
    col.inactive_border=0xff444444
    rounding=10
}
bind=SUPER,RETURN,exec,kitty
bind=SUPER,D,exec,rofi -show drun
bind=SUPER,Q,killactive,
bind=SUPER,E,exec,thunar
bind=SUPER,F,fullscreen
bind=SUPER,T,togglefloating,
bind=SUPER,O,exec,/home/$USERNAME/.config/rofi/scripts/dict.sh
HYPR

# === Waybar config ===
cat <<WAY >/home/$USERNAME/.config/waybar/config.jsonc
{
  "layer": "top",
  "position": "top",
  "modules-left": ["network", "bluetooth", "pulseaudio", "backlight", "battery"],
  "modules-center": ["clock"],
  "modules-right": ["tray"],
  "clock": { "format": "{:%A %H:%M}", "tooltip-format": "{:%Y-%m-%d}" }
}
WAY

# === Rofi dictionary script ===
cat <<DICT >/home/$USERNAME/.config/rofi/scripts/dict.sh
#!/bin/bash
WORD=\$(echo "" | rofi -dmenu -p "Oxford Dict")
if [ -n "\$WORD" ]; then
    sdcv "\$WORD" | rofi -dmenu -i -p "\$WORD"
fi
DICT

chmod +x /home/$USERNAME/.config/rofi/scripts/dict.sh
chown $USERNAME:$USERNAME /home/$USERNAME/.config/rofi/scripts/dict.sh

EOF

echo "[*] Installation complete! Reboot to enjoy your Hyprland setup with Rofi dictionary."
