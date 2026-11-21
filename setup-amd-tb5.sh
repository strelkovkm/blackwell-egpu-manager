#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

echo "=== 1. Running base blackwell-egpu-manager installer ==="
chmod +x install.sh blackwell-egpu
./install.sh

echo "=== 2. Deploying AMD HawkPoint USB4 + Intel TB5 udev & modprobe guards ==="
sudo rm -f /etc/udev/rules.d/99-blackwell-egpu.rules
sudo cp -f "$REPO_DIR/configs/70-blackwell-egpu.rules" /etc/udev/rules.d/70-blackwell-egpu.rules
sudo cp -f "$REPO_DIR/configs/99-blackwell-egpu.conf" /etc/modprobe.d/99-blackwell-egpu.conf
sudo udevadm control --reload-rules
sudo update-initramfs -u

echo "=== 3. Resetting Thunderbolt background auto-enroll ==="
sudo boltctl forget --all 2>/dev/null || true

echo "=== 4. Linking egpu-on / egpu-off helpers into ~/.bashrc ==="
if ! grep -q "egpu-bashrc.sh" "$HOME/.bashrc"; then
    {
        echo ""
        echo "# Blackwell eGPU CLI helpers"
        echo "[ -f \"$REPO_DIR/configs/egpu-bashrc.sh\" ] && source \"$REPO_DIR/configs/egpu-bashrc.sh\""
    } >> "$HOME/.bashrc"
fi

echo "=== Setup complete! Reboot without USB4 cable connected, then use 'egpu-on' and 'egpu-off'. ==="
