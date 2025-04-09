#!/bin/bash

# check for sudo permissions
if ! sudo -n true 2>/dev/null; then
	echo "[sudocheck] please run with sudo permissions"
	exit 1
fi

USERNAME="user-openssl"

echo "[setup] user phase started"
if ! id "$USERNAME" &>/dev/null; then
    echo "[setup] Creating user: $USERNAME"
    sudo useradd -m -s /bin/bash "$USERNAME"
else
    echo "[setup] User $USERNAME already exists"
fi

SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
if [ ! -f "$SUDOERS_FILE" ]; then
    echo "[setup] Granting passwordless sudo to $USERNAME"
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 0440 "$SUDOERS_FILE"
else
    echo "[setup] Sudoers file already exists for $USERNAME"
fi

PHASE1="./phase1.sh"
PHASE2="./phase2.sh"

#running other phases
if [ ! -f "$PHASE1" ]; then
    echo "[setup] ERROR: phase1.sh not found"
    exit 1
fi

if [ ! -f "$PHASE2" ]; then
    echo "[setup] ERROR: phase2.sh not found"
    exit 1
fi

sudo chmod +x "$PHASE1" "$PHASE2"
echo "[setup] Running phase1.sh as $USERNAME..."
sudo -u "$USERNAME" bash "$PHASE1" || { echo "[setup] ERROR: phase1.sh failed."; exit 1; }

echo "[setup] Running phase2.sh as $USERNAME..."
sudo -u "$USERNAME" bash "$PHASE2" || { echo "[setup] ERROR: phase2.sh failed."; exit 1; }

echo "[setup] Setup completed successfully."
