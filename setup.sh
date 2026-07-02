#!/usr/bin/env bash
set -e

echo "===================================================="
echo "  LUKS + TPM1 (Clevis) Auto-Unlock Setup"
echo "===================================================="
echo ""

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0"
  exit 1
fi

echo "[1] Checking TPM device..."
if [[ ! -e /dev/tpm0 ]]; then
  echo "❌ No TPM detected"
  exit 1
fi

echo "✔ TPM detected"
echo ""

echo "[2] Listing LUKS devices..."
lsblk -f

echo ""
echo "Enter LUKS partition (e.g. /dev/sda2):"
read LUKS_DEV

if [[ ! -b "$LUKS_DEV" ]]; then
  echo "Invalid device"
  exit 1
fi

echo ""
echo "[3] Binding LUKS to TPM1 using Clevis..."
echo "This does NOT remove your password."

clevis luks bind -d "$LUKS_DEV" tpm1 '{}'

echo ""
echo "✔ TPM1 binding complete"
echo ""

echo "===================================================="
echo "NEXT STEP:"
echo "1. nixos-rebuild switch"
echo "2. reboot"
echo "===================================================="
