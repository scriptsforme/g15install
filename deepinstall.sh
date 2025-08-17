#!/bin/bash
# ---- Dell G15 Arch Install Script with GRUB + Tela theme + Rounded UI ----
set -euo pipefail

USER_NAME="user"
USER_PASS="password"
ROOT_PASS="password"

ROOT_PART="/dev/nvme0n1p5"
EFI_PART="/dev/nvme0n1p6"

mkfs.ext4 "$ROOT_PART"
mkfs.fat -F32 "$EFI_PART"

mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
pacman -Sy --noconfirm

pacstrap /mnt base linux linux-firmware linux-headers \
intel-ucode nvidia-open-dkms lib32-nvidia-utils \
pipewire pipewire-alsa pipewire-pulse lib32-pipewire wireplumber \
bluez bluez-utils bluez-obex \
networkmanager \
sddm hyprland waybar rofi-wayland foot playerctl \
xdg-desktop-portal-hyprland hyprpolkitagent tlp tlp-rdw \
brightnessctl pamixer pavucontrol grim slurp wl-clipboard fastfetch \
git curl jq python-psutil thunar \
grub efibootmgr os-prober base-devel unzip

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<'EOF'
set -euo pipefail

ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

echo "arch-g15" > /etc/hostname
echo -e "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\tarch-g15.localdomain arch-g15" > /etc/hosts

echo "root:REPLACE_ME_ROOTPASS" | chpasswd
useradd -m -G wheel,network -s /bin/bash REPLACE_ME_USER
echo "REPLACE_ME_USER:REPLACE_ME_USERPASS" | chpasswd
echo "REPLACE_ME_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/REPLACE_ME_USER

# ---- GRUB + Tela theme ----
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || true
mkdir -p /boot/grub/themes
cd /boot/grub/themes
git clone https://github.com/vinceliuice/grub2-themes.git tela-src
cd tela-src
./install.sh -b -t tela --dest /boot/grub/themes
cd ..
rm -rf tela-src
echo 'GRUB_TIMEOUT=4' >> /etc/default/grub
echo 'GRUB_CMDLINE_LINUX="nvidia-drm.modeset=1"' >> /etc/default/grub
echo 'GRUB_THEME="/boot/grub/themes/tela/theme.txt"' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "options nvidia-drm modeset=1" > /etc/modprobe.d/nvidia.conf
mkinitcpio -P

systemctl enable --now NetworkManager
systemctl enable --now bluetooth
systemctl enable --now sddm
systemctl enable --now tlp
systemctl mask systemd-rfkill

# Hyprland config
mkdir -p /home/REPLACE_ME_USER/.config/hypr
cat > /home/REPLACE_ME_USER/.config/hypr/hyprland.conf <<'HYPRCONF'
monitor = eDP-1, 1920x1080@60, 0x0, 1, decoration_corner_radius=12
monitor = HDMI-A-1, 2560x1080@60, 1920x0, 1, decoration_corner_radius=12

general {
    border_size = 0
    gaps_in = 8
    gaps_out = 12
    col.active_border = rgba(00000000)
    col.inactive_border = rgba(00000000)
    decoration {
        rounding = 12
    }
}

exec = hyprpaper
exec = waybar
HYPRCONF

# Hyprpaper config
mkdir -p /home/REPLACE_ME_USER/.config/hyprpaper
cat > /home/REPLACE_ME_USER/.config/hyprpaper/hyprpaper.conf <<'HPAPER'
preload = /home/REPLACE_ME_USER/Pictures/wallpaper.jpg
wallpaper = eDP-1,/home/REPLACE_ME_USER/Pictures/wallpaper.jpg
HPAPER

mkdir -p /home/REPLACE_ME_USER/Pictures
if [ ! -f /home/REPLACE_ME_USER/Pictures/wallpaper.jpg ]; then
  convert -size 1920x1080 xc:"#1e1e2e" /home/REPLACE_ME_USER/Pictures/wallpaper.jpg || true
fi

# Waybar (rounded, borderless)
mkdir -p /home/REPLACE_ME_USER/.config/waybar
cat > /home/REPLACE_ME_USER/.config/waybar/config <<'WAYCONF'
{
  "layer": "top",
  "position": "top",
  "modules-left": ["sway/workspaces", "network"],
  "modules-center": ["clock"],
  "modules-right": ["pulseaudio","bluetooth","battery","custom/power"]
}
WAYCONF

cat > /home/REPLACE_ME_USER/.config/waybar/style.css <<'WSTYLE'
* {
  border: none;
  border-radius: 12px;
  background-color: rgba(30,30,30,0.6);
  color: #D9E0EE;
  padding: 6px 10px;
  backdrop-filter: blur(10px);
}
WSTYLE

# Rofi rounded, borderless
mkdir -p /home/REPLACE_ME_USER/.config/rofi
cat > /home/REPLACE_ME_USER/.config/rofi/config.rasi <<'ROFI'
configuration {
  modi: "drun,run";
  show-icons: true;
}
window {
  background-color: rgba(30,30,30,230);
  border: 0px;
  border-radius: 12px;
}
element {
  padding: 8px;
}
ROFI

# wlogout config (rounded)
mkdir -p /home/REPLACE_ME_USER/.config/wlogout
cat > /home/REPLACE_ME_USER/.config/wlogout/layout <<'WLOG'
{
    "label": "lock",
    "action": "hyprlock",
    "text": "Lock",
    "keybind": "l"
},
{
    "label": "logout",
    "action": "pkill -KILL -u $USER",
    "text": "Logout",
    "keybind": "e"
},
{
    "label": "reboot",
    "action": "systemctl reboot",
    "text": "Reboot",
    "keybind": "r"
},
{
    "label": "shutdown",
    "action": "systemctl poweroff",
    "text": "Shutdown",
    "keybind": "s"
}
WLOG

# Hyprlock basic
mkdir -p /home/REPLACE_ME_USER/.config/hyprlock
cat > /home/REPLACE_ME_USER/.config/hyprlock/config.conf <<'LOCKCONF'
background = #1e1e2e
input-field {
    inner-color = #2e2e3e
    outer-color = #00000000
    rounding = 12
}
LOCKCONF

# Build AUR pkgs if missing
cd /tmp
for pkg in wlogout hyprlock hyprpaper; do
  if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
    git clone https://aur.archlinux.org/$pkg.git
    cd $pkg
    yes | makepkg -si
    cd ..
  fi
done

chown -R REPLACE_ME_USER:REPLACE_ME_USER /home/REPLACE_ME_USER
EOF

# Replace placeholders
sed -i "s/REPLACE_ME_USER/$USER_NAME/g" /mnt/etc/sudoers.d/REPLACE_ME_USER
sed -i "s/REPLACE_ME_USER/$USER_NAME/g" /mnt/home/$USER_NAME/.config/* || true
sed -i "s/REPLACE_ME_USERPASS/$USER_PASS/g" /mnt/etc/shadow || true
sed -i "s/REPLACE_ME_ROOTPASS/$ROOT_PASS/g" /mnt/etc/shadow || true

echo "Kurulum tamam! GRUB Tela theme, Hyprland borderless + rounded, wlogout/hyprlock/hyprpaper hazır."
