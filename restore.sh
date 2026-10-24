#!/usr/bin/env bash
# Sets up a new Ubuntu machine from this repo. Run on the new machine with:
#   git clone https://github.com/PatrickReynoldsCoding/linux.git ~/linux
#   bash ~/linux/restore.sh            # everything
#   bash ~/linux/restore.sh --no-apps  # skip install-apps.sh (settings only)
# Safe to re-run. Anything that fails is listed at the end instead of stopping the script.

set -u
cd "$(dirname "$0")"
FAILED=()

# ---------------------------------------------------------------------------
# 1. Apps (the hand-picked list, which also sets up Chrome/Steam/Waydroid repos)
# ---------------------------------------------------------------------------
if [ "${1:-}" != "--no-apps" ]; then
  echo "== Running install-apps.sh =="
  bash ./install-apps.sh || FAILED+=("install-apps.sh")
fi

# ---------------------------------------------------------------------------
# 2. Anything else that was installed on the old machine
# ---------------------------------------------------------------------------
echo "== apt packages from the old machine =="
while read -r pkg; do
  [ -z "$pkg" ] && continue
  dpkg -s "$pkg" >/dev/null 2>&1 && continue
  echo ">> apt: $pkg"
  sudo apt-get install -y "$pkg" || FAILED+=("apt: $pkg")
done < packages/apt.txt

echo "== Snaps =="
installed_snaps=$(snap list 2>/dev/null | awk 'NR > 1 { print $1 }')
while read -r name flags; do
  [ -z "$name" ] && continue
  grep -qx "$name" <<< "$installed_snaps" && continue
  echo ">> snap: $name $flags"
  sudo snap install "$name" $flags || FAILED+=("snap: $name")
done < packages/snap.txt

echo "== Flatpaks =="
while read -r app; do
  [ -z "$app" ] && continue
  flatpak info "$app" >/dev/null 2>&1 && continue
  echo ">> flatpak: $app"
  flatpak install -y --noninteractive flathub "$app" || FAILED+=("flatpak: $app")
done < packages/flatpak.txt

if [ -s packages/vscode.txt ] && command -v code >/dev/null; then
  echo "== VS Code extensions =="
  while read -r ext; do
    code --install-extension "$ext" || FAILED+=("vscode: $ext")
  done < packages/vscode.txt
fi

# ---------------------------------------------------------------------------
# 3. GNOME extensions (downloaded from extensions.gnome.org for this GNOME version)
# ---------------------------------------------------------------------------
echo "== GNOME extensions =="
shell_version=$(gnome-shell --version | grep -oE '[0-9]+' | head -1)
while read -r uuid; do
  [ -z "$uuid" ] && continue
  echo ">> extension: $uuid"
  url=$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$shell_version" \
        | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["download_url"])' 2>/dev/null)
  if [ -z "$url" ]; then
    FAILED+=("extension $uuid (no version for GNOME $shell_version)")
    continue
  fi
  zip=$(mktemp --suffix=.zip)
  { curl -fsSL -o "$zip" "https://extensions.gnome.org$url" \
    && gnome-extensions install --force "$zip"; } || FAILED+=("extension: $uuid")
  rm -f "$zip"
done < config/gnome-extensions.txt

# ---------------------------------------------------------------------------
# 4. Dotfiles (existing files are kept as <name>.bak)
# ---------------------------------------------------------------------------
echo "== Dotfiles =="
(cd home && find . -type f) | while read -r f; do
  f=${f#./}
  mkdir -p "$HOME/$(dirname "$f")"
  if [ -f "$HOME/$f" ] && ! cmp -s "home/$f" "$HOME/$f"; then
    cp "$HOME/$f" "$HOME/$f.bak"
  fi
  cp "home/$f" "$HOME/$f"
done

# ---------------------------------------------------------------------------
# 5. GNOME settings, keyboard shortcuts, dock, theme, enabled extensions
# ---------------------------------------------------------------------------
echo "== GNOME settings =="
dconf load / < config/gnome.dconf || FAILED+=("GNOME settings (dconf load)")

echo
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "All done."
else
  echo "Done, but these failed (re-run the script or fix by hand):"
  printf '  - %s\n' "${FAILED[@]}"
fi
echo
echo "Log out and back in so GNOME loads the extensions."
echo "Not in this repo (copy by hand): ~/.ssh keys, 'gh auth login', browser sign-in."
