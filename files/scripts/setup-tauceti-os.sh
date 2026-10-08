#!/bin/bash
set -euo pipefail

# --- 1. PRE-INSTALL IDENTITY ---
groupadd -r docker || true

# --- 2. AUTOMATED CLEANUP ---
echo "⚙️ Setting up First-Boot optimization service..."
chmod +x /usr/libexec/tauceti-os-optimization.sh
chmod +x /usr/libexec/tauceti-os-provision.sh

# --- 3. ENABLE SYSTEMD UNITS IN THE VENDOR LAYER ---
mkdir -p /usr/lib/systemd/system/multi-user.target.wants

ln -sf ../tauceti-os-provision.service \
    /usr/lib/systemd/system/multi-user.target.wants/tauceti-os-provision.service

echo "✅ Tauceti-OS Custom Assembly Complete! Ready for Deployment."

