#!/usr/bin/env bash
# Ubuntu app installer - rebuilt from the software on Patrick's Windows laptop.
# Run on the new Ubuntu install with:   bash install-apps.sh
# Safe to re-run. Anything that fails is listed at the end instead of stopping the script.
# Delete or comment out (#) any line you don't want.

set -u
FAILED=()

apt_i()     { echo ">> apt: $*";     sudo apt-get install -y "$@"           || FAILED+=("apt: $*"); }
snap_i()    { echo ">> snap: $*";    sudo snap install "$@"                 || FAILED+=("snap: $*"); }
flatpak_i() { echo ">> flatpak: $1"; flatpak install -y --noninteractive flathub "$1" || FAILED+=("flatpak: $1"); }

echo "== Updating system =="
sudo apt-get update && sudo apt-get upgrade -y

echo "== Package tools =="
apt_i curl wget gpg ca-certificates software-properties-common flatpak gnome-software-plugin-flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# ---------------------------------------------------------------------------
# Everyday apps
# ---------------------------------------------------------------------------
echo "== Everyday apps =="
apt_i vlc qbittorrent 7zip unrar ffmpeg pandoc solaar      # solaar = Logitech device manager (replaces Logi apps)
apt_i lm-sensors                                           # replaces Core Temp (run: sensors)
apt_i yacreader                                            # comic reader (replaces YACReader / CDisplayEx)

flatpak_i com.discordapp.Discord
flatpak_i com.spotify.Client
flatpak_i com.stremio.Stremio
flatpak_i us.zoom.Zoom
# Firefox comes pre-installed on Ubuntu.

# Google Chrome (official .deb, adds its own update repo)
echo ">> Google Chrome"
wget -qO /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
  && sudo apt-get install -y /tmp/chrome.deb || FAILED+=("Google Chrome")

# ---------------------------------------------------------------------------
# Gaming
# ---------------------------------------------------------------------------
echo "== Gaming =="
# Steam (official .deb from Valve - sets up the 32-bit libraries it needs)
echo ">> Steam"
wget -qO /tmp/steam.deb https://cdn.akamai.steamstatic.com/client/installer/steam.deb \
  && sudo apt-get install -y /tmp/steam.deb || FAILED+=("Steam")
# After first launch: Steam > Settings > Compatibility > enable Steam Play for all titles.

# ---------------------------------------------------------------------------
# Creative
# ---------------------------------------------------------------------------
echo "== Creative =="
# Optional - uncomment if wanted:
flatpak_i com.bitwig.BitwigStudio      # closest Linux DAW to Ableton (paid)
# ---------------------------------------------------------------------------
# Development
# ---------------------------------------------------------------------------
echo "== Dev tools =="
apt_i git gh build-essential cmake python3 python3-pip python3-venv pipx \
      nodejs npm default-jdk qemu-system-x86 qemu-utils

snap_i code --classic                        # VS Code
snap_i intellij-idea-community --classic
snap_i postman

# uv (Python tool manager) + your Python tools
echo ">> uv"
curl -LsSf https://astral.sh/uv/install.sh | sh || FAILED+=("uv")
export PATH="$HOME/.local/bin:$PATH"
uv tool install aider-chat || FAILED+=("aider-chat")
pipx install yt-dlp        || FAILED+=("yt-dlp")     # replaces YouTube Playlist Downloader
pipx install zotify        || FAILED+=("zotify")
pipx ensurepath

# Global npm packages
sudo npm install -g eslint || FAILED+=("npm: eslint")

# Claude Code
echo ">> Claude Code"
curl -fsSL https://claude.ai/install.sh | bash || FAILED+=("Claude Code")

# ---------------------------------------------------------------------------
# Theme - WhiteSur (macOS-style) GTK theme
# ---------------------------------------------------------------------------
echo "== WhiteSur theme =="
apt_i sassc libglib2.0-dev-bin gnome-tweaks gnome-shell-extensions
rm -rf /tmp/WhiteSur-gtk-theme
{ git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git /tmp/WhiteSur-gtk-theme \
  && (cd /tmp/WhiteSur-gtk-theme && ./install.sh -l && ./tweaks.sh -F) \
  && gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark' \
  && gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'; } || FAILED+=("WhiteSur theme")
# -l = also theme newer GTK4/libadwaita apps, tweaks.sh -F = also theme Flatpak apps.
# For the light version use 'WhiteSur-Light' and 'prefer-light' above.
# Fine-tune afterwards in the Tweaks app (installed above).



echo
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "All done - everything installed."
else
  echo "Done, but these failed (re-run the script or install them by hand):"
  printf '  - %s\n' "${FAILED[@]}"
fi
