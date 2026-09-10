# Contributing

This directory is the live Omarchy plugin
`io.github.mrdulasolutions.pair`. Saving QML reloads it in `omarchy-shell`.

```sh
omarchy plugin validate ~/.config/omarchy/plugins/io.github.mrdulasolutions.pair
./scripts/pair-ctl status --check-latest
omarchy-shell shell rescanPlugins
```

## Two artifacts

1. **This plugin** — bar widget + `scripts/pair-ctl`. Update with
   `omarchy plugin update io.github.mrdulasolutions.pair`.
2. **NVIDIA PAIR** — `~/.local/opt/PAIR`. Update with `pair-ctl update`.
   Never `apt install` the `.deb` on Omarchy. Never use PAIR’s in-app updater.

## Install / launch (no plugin install hooks)

```sh
./scripts/pair-ctl install
./scripts/pair-ctl launch
```

`pair-ctl firewall` is the only command that needs sudo. It opens a
visible terminal and allows LAN TCP 14318–14323 and UDP 5353.

## Do not

- Edit `/usr/share/omarchy/` or write to `/opt/PAIR`
- Rewrite `shell.json` except `pair-ctl hide-tray` after an explicit user
  click (adds NVIDIA’s tray id to `omarchy.tray.hidden`)
- Put `AGENTS.md` or other agent-instruction files in the plugin tree
