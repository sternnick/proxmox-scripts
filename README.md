# Proxmox Docker VM Setup Script

This repository provides a script to automatically create a Docker-ready virtual machine on **Proxmox VE**, based on **Debian 12 Cloud Image**.  
The VM includes Docker CE and Docker Compose, properly pre-installed and configured.

---

## ✨ Features

- 🐳 Docker CE + Compose pre-installed
- 📦 Uses official **Debian 12 nocloud qcow2 image**
- 🔁 Automatically resizes disk to your specified size
- ⚡ Fast creation via `virt-customize` and `qm` tooling
- 🧰 Clean and local – no telemetry or branding
- 🔐 MIT licensed, fully open source

---

## ⚙️ Requirements

- ✅ Proxmox VE 8.x or 9.0 (not 9.1+ yet)
- ✅ `amd64` architecture (not ARM)
- ✅ Internet access to download the Debian image
- ✅ Root access on Proxmox shell (not via SSH ideally)

---

## 🚀 Usage

Make sure you have `libguestfs-tools` installed on the Proxmox host (the script will auto-install it if missing):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/proxmox-scripts/main/docker-vm.sh)"
