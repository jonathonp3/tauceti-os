#!/bin/bash
set -euo pipefail

# Configuration
REMOTE_NAME="tauceti-os-apps"
REMOTE_URL="https://jonathonp3.github.io/tauceti-os-apps/"
GPG_URL="https://raw.githubusercontent.com/jonathonp3/tauceti-os-apps/main/tauceti-os-apps.gpg"
GPG_TEMP="/tmp/tauceti-os-apps.gpg"
APP_ID="org.gnome.TextEditor"
LOG_FILE="/var/log/tauceti-os-optimization.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

log "🚀 Starting Tauceti-OS First-Boot Optimization..."

# 1. Integrity Check: Fix any interrupted previous attempts
# Using timeout to prevent hanging, and true to always return success
log "🔧 Running flatpak repair (may take several minutes)..."
timeout 300 flatpak repair --system --verbose || {
    exit_code=$?
    if [ $exit_code -eq 124 ]; then
        log "⚠️  flatpak repair timed out after 5 minutes, continuing anyway..."
    else
        log "⚠️  flatpak repair exited with code $exit_code, continuing..."
    fi
}

# 2. Ensure Flathub is enabled system-wide for dependencies (GNOME Platform)
log "📦 Ensuring Flathub is available for runtimes..."
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
flatpak remote-modify --system --enable flathub 2>/dev/null || true

# 3. Add Tauceti-OS Custom App Store
log "📦 Connecting to Tauceti-OS App Store..."
if wget2 -q -O "$GPG_TEMP" "$GPG_URL" 2>/dev/null || wget -q -O "$GPG_TEMP" "$GPG_URL" 2>/dev/null; then
    if [[ -f "$GPG_TEMP" && -s "$GPG_TEMP" ]]; then
        flatpak remote-add --system --if-not-exists --gpg-import="$GPG_TEMP" "$REMOTE_NAME" "$REMOTE_URL" 2>/dev/null || true
        rm -f "$GPG_TEMP"
    fi
else
    log "⚠️  Could not download GPG key, continuing without Tauceti-OS repo..."
fi

# 4. Check if the Tauceti-OS version of the app is already installed
if flatpak list --system --columns=application,origin 2>/dev/null | grep -qE "${APP_ID}.*${REMOTE_NAME}"; then
    log "✅ Tauceti-OS Custom Editor is already active. Checking for updates..."
    flatpak update --system -y "$APP_ID" 2>/dev/null || true
else
    log "🔄 Swapping stock editor for Tauceti-OS Custom version..."
    flatpak uninstall --system -y "$APP_ID" 2>/dev/null || true
    if flatpak install --system -y "$REMOTE_NAME" "$APP_ID" 2>/dev/null; then
        log "✅ Tauceti-OS Custom Editor installed successfully"
    else
        log "⚠️  Failed to install Tauceti-OS Custom Editor, continuing..."
    fi
fi

# 5. Tauceti-OS App Hardening: Element/Riot Keyring Fix
log "🔐 Hardening Element/Riot Keyring Integration..."
flatpak override --system \
  --filesystem=/run/dbus/system_bus_socket \
  --talk-name=org.freedesktop.secrets \
  --env=PASSWORD_STORE=gnome-libsecret \
  im.riot.Riot 2>/dev/null || true

# 6. Apply Global Theming Override
log "🎨 Applying theming overrides..."
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null || true

# 7. Final Optimization: Remove unused runtimes to save space
log "🧹 Removing unused runtimes..."
flatpak uninstall --system --unused -y 2>/dev/null || true

# 8. Remove old Gnome Extensions app
log "📦 Removing old Gnome Extensions app..."
flatpak remove -y org.gnome.Extensions 2>/dev/null || {
    log "ℹ️  org.gnome.Extensions not found or already removed"
}

# 9. Install Flatpaks
log "📦 Installing required Flatpaks..."

# Array of flatpaks to install
flatpaks=(
    "com.github.tchx84.Flatseal"
    "com.mattjakeman.ExtensionManager"
    "com.spotify.Client"
    "im.riot.Riot"
    "it.mijorus.gearlever"
    "org.freac.freac"
    "org.kde.kid3"
    "org.keepassxc.KeePassXC"
    "org.gnome.SimpleScan"
    "org.gnome.gThumb"
    "org.gnome.Rhythmbox3"
    "org.libreoffice.LibreOffice"
    "org.mozilla.thunderbird_esr"
    "org.nextcloud.Nextcloud"
    "org.telegram.desktop"
    "com.transmissionbt.Transmission"
)

for app in "${flatpaks[@]}"; do
    log "📦 Installing $app..."
    if flatpak install --system -y flathub "$app" 2>/dev/null; then
        log "✅ $app installed successfully"
    else
        log "❌ Failed to install $app"
    fi
done

# 10. Disable the service after first boot (since it's a one-time optimization)
log "🔧 Disabling first-boot service..."
systemctl disable tauceti-os-optimization.service 2>/dev/null || true
log "✅ Service disabled for future boots"

log "✨ Tauceti-OS Optimization tasks complete."
log "📋 Log saved to: $LOG_FILE"

# Always exit with 0 to prevent systemd from retrying
exit 0
