#!/usr/bin/env bash
# Saves this machine's setup into the repo: GNOME settings + shortcuts, extensions,
# installed packages and dotfiles. Run it whenever you change something, then:
#   git add -A && git commit -m "Update backup" && git push
# THIS REPO IS PUBLIC - never add files with passwords, tokens or keys.

set -euo pipefail
cd "$(dirname "$0")"

# Dotfiles to save, relative to $HOME. Missing ones are skipped.
# Do NOT add ~/.ssh, ~/.config/gh (GitHub token) or browser profiles.
DOTFILES=(
  .bashrc
  .zshrc
  .profile
  .config/mimeapps.list
  .config/Code/User/settings.json
  .config/Code/User/keybindings.json
  .claude/settings.json
  .claude/hooks
)

# GNOME settings sections that are only timestamps or window sizes - not worth saving.
DCONF_SKIP='^\[(apps/update-manager|com/ubuntu/update-notifier|org/gnome/software|org/gnome/control-center|org/gnome/nautilus/window-state|org/gnome/evolution-data-server|org/gnome/Ptyxis)\]$'

mkdir -p config packages home

echo "== GNOME settings, shortcuts and extension settings =="
dconf dump / | awk -v skip="$DCONF_SKIP" '
  /^\[/ { drop = ($0 ~ skip) }
  !drop' > config/gnome.dconf

echo "== GNOME extensions you installed =="
ls "$HOME/.local/share/gnome-shell/extensions" 2>/dev/null > config/gnome-extensions.txt || true

echo "== Package lists =="
apt-mark showmanual | sort > packages/apt.txt
snap list 2>/dev/null | awk 'NR > 1 { print $1, ($6 ~ /classic/ ? "--classic" : "") }' > packages/snap.txt || true
flatpak list --app --columns=application 2>/dev/null | sort > packages/flatpak.txt || true
command -v code >/dev/null && code --list-extensions > packages/vscode.txt || true

echo "== Dotfiles =="
rm -rf home && mkdir home
for f in "${DOTFILES[@]}"; do
  if [ -e "$HOME/$f" ]; then
    mkdir -p "home/$(dirname "$f")"
    cp -r "$HOME/$f" "home/$f"
  fi
done

echo "== System files =="
mkdir -p config/system
[ -f /etc/udev/rules.d/90-lid-no-wakeup.rules ] && cp /etc/udev/rules.d/90-lid-no-wakeup.rules config/system/ || true

echo "== Checking for secrets =="
if grep -rniE '(password|passwd|secret|token|api[_-]?key|BEGIN [A-Z ]*PRIVATE KEY)[[:space:]]*[=:]' home config; then
  echo "!! The lines above look like secrets. Remove them before committing - this repo is public."
  exit 1
fi

echo
echo "Done. Review with 'git status' / 'git diff', then commit and push."
