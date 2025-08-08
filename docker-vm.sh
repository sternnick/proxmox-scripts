#!/usr/bin/env bash
set -e

# Based on: https://github.com/community-scripts/ProxmoxVE
# Original Authors: thost96, michelroegl-brunner
# Modified by: sternnick (https://github.com/sternnick)
# License: MIT

# === ΠΡΟΕΤΟΙΜΑΣΙΑ ===
VMID=$(pvesh get /cluster/nextid)
DISK_SIZE="10G"
RAM="4096"
CPUS="2"
BRIDGE="vmbr0"
MAC="02:$(openssl rand -hex 5 | sed 's/\(..\)/\1:/g; s/:$//')"
HOSTNAME="docker"
STORAGE="local-lvm"
ARCH=$(dpkg --print-architecture)
IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-${ARCH}.qcow2"
IMAGE_FILE=$(basename $IMAGE_URL)

# === ΕΛΕΓΧΟΙ ===
if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root."
  exit 1
fi

if ! pveversion | grep -Eq '^pve-manager/(8\.|9\.0)'; then
  echo "Supported only on Proxmox VE 8.x or 9.0"
  exit 1
fi

if [ "$ARCH" != "amd64" ]; then
  echo "Only amd64 is supported (not ARM/PiMox)."
  exit 1
fi

# === ΛΗΨΗ ΕΙΚΟΝΑΣ ===
echo "[+] Downloading Debian Cloud image..."
curl -fSL -o "$IMAGE_FILE" "$IMAGE_URL"

# === ΕΓΚΑΤΑΣΤΑΣΗ libguestfs-tools ===
if ! command -v virt-customize &>/dev/null; then
  echo "[+] Installing libguestfs-tools..."
  apt-get update -qq
  apt-get install -y libguestfs-tools
fi

# === ΠΡΟΣΘΗΚΗ DOCKER ===
echo "[+] Adding Docker to image..."
virt-customize -a "$IMAGE_FILE" \
  --install qemu-guest-agent,apt-transport-https,ca-certificates,curl,gnupg,lsb-release \
  --run-command "mkdir -p /etc/apt/keyrings" \
  --run-command "curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg" \
  --run-command "echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable' > /etc/apt/sources.list.d/docker.list" \
  --run-command "apt-get update -qq && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin" \
  --run-command "systemctl enable docker" \
  --run-command "echo -n > /etc/machine-id" \
  --hostname "$HOSTNAME"

# === RESIZE IMAGE ===
echo "[+] Resizing image..."
qemu-img create -f qcow2 expanded.qcow2 $DISK_SIZE
virt-resize --expand /dev/sda1 "$IMAGE_FILE" expanded.qcow2
mv expanded.qcow2 "$IMAGE_FILE"

# === ΔΗΜΙΟΥΡΓΙΑ VM ===
echo "[+] Creating VM $VMID..."
qm create $VMID \
  --name "$HOSTNAME" \
  --memory $RAM \
  --cores $CPUS \
  --net0 virtio,bridge=$BRIDGE,macaddr=$MAC \
  --scsihw virtio-scsi-pci \
  --agent enabled=1 \
  --ostype l26 \
  --serial0 socket \
  --bios ovmf \
  --machine q35 \
  --onboot 1

# === ΕΙΣΑΓΩΓΗ ΔΙΣΚΟΥ ===
echo "[+] Importing disk..."
qm importdisk $VMID "$IMAGE_FILE" "$STORAGE" --format qcow2
qm set $VMID \
  --scsi0 "${STORAGE}:vm-${VMID}-disk-0,discard=on,ssd=1,size=${DISK_SIZE}" \
  --efidisk0 "${STORAGE}:vm-${VMID}-disk-1,efitype=4m" \
  --boot order=scsi0

# === ΕΝΑΡΞΗ ===
echo "[+] Starting VM..."
qm start $VMID

echo "[✓] Docker VM created and started with ID $VMID"
