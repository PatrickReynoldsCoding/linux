# linux

My Ubuntu setup: apps, GNOME settings, keyboard shortcuts, extensions and dotfiles.

## New machine

```bash
sudo apt-get install -y git
git clone https://github.com/PatrickReynoldsCoding/linux.git ~/linux
bash ~/linux/restore.sh
```

Then log out and back in. After that, by hand:

- copy `~/.ssh` from the old machine (or make new keys)
- `gh auth login`
- sign in to Chrome (it syncs bookmarks and extensions)

`bash restore.sh --no-apps` skips `install-apps.sh` and only restores the rest.

## Saving changes from this machine

```bash
cd ~/linux
bash backup.sh
git add -A && git commit -m "Update backup" && git push
```

## What's in here

| Path | What |
|---|---|
| `install-apps.sh` | Hand-picked apps, with the extra repos they need (Chrome, Steam, Waydroid, WhiteSur theme) |
| `backup.sh` | Saves this machine's setup into the repo |
| `restore.sh` | Sets up a new machine from the repo |
| `config/gnome.dconf` | GNOME settings: keyboard shortcuts, dock, theme, night light, extension settings |
| `config/gnome-extensions.txt` | Extensions installed from extensions.gnome.org |
| `packages/` | Everything installed with apt, snap and flatpak |
| `home/` | Dotfiles, copied into `~` on restore |

**This repo is public.** Never add SSH keys, `~/.config/gh` or anything with passwords or tokens.
`backup.sh` stops if it finds anything that looks like a secret.
