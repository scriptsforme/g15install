#!/bin/bash
# Dell G15 5530 Arch Linux + Hyprland DE-like setup
# By ChatGPT

set -e

# === CONFIG ===
DISK_ROOT="/dev/nvme0n1p5"
DISK_BOOT="/dev/nvme0n1p6"
HOSTNAME="archg15"
USERNAME="archuser"
PASSWORD="1234"
TIMEZONE="Europe/Istanbul"
KEYMAP="trq"
LOCALE="en_US.UTF-8 UTF-8"

echo "[+] Format disks..."
mkfs.ext4 -F $DISK_ROOT
mkfs.fat -F32 $DISK_BOOT

echo "[+] Mounting..."
mount $DISK_ROOT /mnt
mkdir -p /mnt/boot
mount $DISK_BOOT /mnt/boot

echo "[+] Base install..."
pacstrap -K /mnt base linux-lts linux-firmware vim git networkmanager grub efibootmgr \
    sudo bash-completion sof-firmware alsa-ucm-conf pipewire pipewire-pulse wireplumber

echo "[+] Generate fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "[+] Chroot..."
arch-chroot /mnt /bin/bash <<EOF
echo "[+] Timezone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "[+] Locale..."
echo "$LOCALE" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "[+] Hostname..."
echo "$HOSTNAME" > /etc/hostname

echo "[+] Root password..."
echo "root:$PASSWORD" | chpasswd

echo "[+] User..."
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

echo "[+] Bootloader..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1 intel_iommu=on iommu=pt"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "[+] Enable services..."
systemctl enable NetworkManager
systemctl enable bluetooth

echo "[+] Desktop stack..."
pacman -S --noconfirm hyprland waybar kitty rofi mako thunar \
    ttf-jetbrains-mono-nerd ttf-font-awesome bluez bluez-utils \
    brightnessctl playerctl pavucontrol nm-connection-editor \
    blueman xdg-desktop-portal-hyprland xdg-desktop-portal-gtk

echo "[+] NVIDIA drivers..."
pacman -S --noconfirm nvidia-open nvidia-utils nvidia-settings mesa vulkan-intel

# === SOUND FIX (HDMI-only issue) ===
echo "[+] Sound fix..."
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/alsa-base.conf <<FIX
options snd_hda_intel dmic_detect=0
options snd-hda-intel model=dell-headset-multi
FIX

# === Hyprland config ===
echo "[+] Configs..."
mkdir -p /home/$USERNAME/.config/{hypr,waybar}
cat > /home/$USERNAME/.config/hypr/hyprland.conf <<HYP
monitor=,preferred,auto,1
exec-once = waybar & mako & nm-applet & blueman-applet & pavucontrol --daemon
input {
  kb_layout=tr
  follow_mouse=1
}
general {
  gaps_in=5
  gaps_out=10
  border_size=2
  col.active_border=0xffa6e3a1
}
bind=SUPER,Return,exec,kitty
bind=SUPER,D,exec,rofi -show drun
bind=SUPER,E,exec,thunar
bind=SUPER,Q,killactive,
bind=SUPER,F,fullscreen,
HYP

cat > /home/$USERNAME/.config/waybar/config <<WAY
{
  "layer": "top",
  "height": 32,
  "modules-left": ["custom/launcher", "cpu", "memory", "temperature"],
  "modules-center": ["clock"],
  "modules-right": ["network", "pulseaudio", "backlight", "battery", "tray"],

  "custom/launcher": {
    "format": "",
    "on-click": "rofi -show drun"
  },

  "cpu": { "format": " {usage}%" },
  "memory": { "format": " {used}G" },

  "temperature": {
    "hwmon-path": "/sys/class/thermal/thermal_zone0/temp",
    "format": " {temperatureC}°C",
    "critical-threshold": 80,
    "format-critical": " {temperatureC}°C"
  },

  "clock": { "format": " {:%H:%M  %d.%m.%Y}" },

  "network": {
    "format-wifi": " {essid}",
    "format-ethernet": "󰈁 {ifname}",
    "format-disconnected": "󰖪"
  },

  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-muted": "󰝟 mute",
    "on-click": "pavucontrol"
  },

  "backlight": { "format": " {percent}%" },

  "battery": {
    "format": "{icon} {capacity}%",
    "format-icons": ["","","","",""]
  }
}
WAY

cat > /home/$USERNAME/.config/waybar/style.css <<CSS
* {
  font-family: JetBrainsMono Nerd Font;
  font-size: 12px;
  color: #cdd6f4;
}
window#waybar {
  background-color: rgba(30, 30, 46, 0.9);
  border-radius: 12px;
}
#battery, #cpu, #memory, #temperature, #backlight, #pulseaudio, #network, #tray {
  padding: 0 10px;
}
CSS

chown -R $USERNAME:$USERNAME /home/$USERNAME/.config
EOF

echo "[+] Done! Reboot and enjoy Hyprland DE-style."
