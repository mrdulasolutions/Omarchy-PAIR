# Agent notes: NVIDIA PAIR on Omarchy

You are installing or updating **NVIDIA Personal AI Router (PAIR)** on Omarchy Linux.

This is **not** NVIDIA NIM, NeMo, TensorRT-LLM, or a new inference engine.
PAIR is a local router in front of Ollama / LM Studio.
Official project: https://github.com/NVIDIA/Personal-AI-Router

Omarchy is Arch-based (`ID_LIKE=arch`). NVIDIA’s Linux installer is a `.deb`.
**Never** `apt install` that package here. Install/update of the app needs no sudo.
**Do** use sudo for `pair-ctl firewall` — Omarchy ufw otherwise blocks pairing.

## If the user asked you to install PAIR

1. If this plugin is not already in `~/.config/omarchy/plugins/io.github.mrdulasolutions.pair/`:

   ```sh
   omarchy plugin add https://github.com/mrdulasolutions/Omarchy-PAIR.git --enable --yes
   ```

   `omarchy plugin add` only clones QML. It does **not** download PAIR.

2. Install the NVIDIA app (user-local, ~135 MB):

   ```sh
   ~/.config/omarchy/plugins/io.github.mrdulasolutions.pair/scripts/pair-ctl install
   ```

3. Launch it:

   ```sh
   ~/.config/omarchy/plugins/io.github.mrdulasolutions.pair/scripts/pair-ctl launch
   ```

4. Confirm `pair-ctl status --check-latest` prints `"installed": true`.

## If the user asked you to update PAIR

There are **two** artifacts. Update the one they meant; when unsure, update both.

### A. NVIDIA PAIR **app** (the thing that serves `127.0.0.1:11434`)

**Do not** click PAIR’s in-app updater. It expects Debian `apt` and `/opt/PAIR`.
**Do not** download a `.deb` and `apt install` it.

```sh
~/.config/omarchy/plugins/io.github.mrdulasolutions.pair/scripts/pair-ctl update
```

That fetches the latest GitHub release of `NVIDIA/Personal-AI-Router`,
replaces `~/.local/opt/PAIR`, and keeps cluster settings.

Pin a release:

```sh
~/.config/omarchy/plugins/io.github.mrdulasolutions.pair/scripts/pair-ctl install --version v0.1.1
```

### B. This **Omarchy plugin** (bar widget + `pair-ctl`)

```sh
omarchy plugin update io.github.mrdulasolutions.pair --yes
```

Then, if `scripts/pair-ctl` changed, you still need step A to refresh the NVIDIA binary.

## Commands

```sh
pair-ctl= ~/.config/omarchy/plugins/io.github.mrdulasolutions.pair/scripts/pair-ctl

$pair-ctl status                 # local JSON, no network
$pair-ctl status --check-latest  # also hits GitHub
$pair-ctl install                # download + unpack latest
$pair-ctl update                 # install latest if newer
$pair-ctl launch                 # desktop app
$pair-ctl stop
$pair-ctl firewall               # sudo: allow LAN PAIR ports in ufw
$pair-ctl uninstall              # keep ~/.config PAIR data
$pair-ctl uninstall --purge      # also wipe PAIR cluster identity
```

`pair-ctl` prints one JSON object on stdout and progress on stderr.

## Paths this plugin owns

- `~/.local/opt/PAIR` — app
- `~/.local/bin/nvpair-desktop` — GUI
- `~/.local/bin/nvpair` — TUI (do not run while the GUI is open)
- `~/.local/share/applications/nvpair.desktop`
- `~/.local/state/omarchy-pair/installed.json`

Do **not** write to `/opt/PAIR` or `/usr`.
Do **not** edit `/usr/share/omarchy/`.

## After install, tell the user

- This plugin is the only PAIR chip. It hides NVIDIA’s Electron tray icon (`pair-ctl hide-tray`) because that tray popup closes when you leave the Omarchy bar.
- PAIR window: first-run can install Ollama (default) or LM Studio.
- Apps should use `http://127.0.0.1:11434` (Ollama) or `http://127.0.0.1:1234` (OpenAI).
- Pairing other PCs uses a six-digit PIN on the same LAN.
- A machine without an NVIDIA GPU can still run PAIR as a router node.
- If pairing fails, fix the firewall first (below). It is not a missing LLM.

## Pairing / “already in another cluster” / no PIN on Linux

Omarchy `ufw` defaults to **deny incoming**. PAIR listens on `*:14321`, but the
kernel drops the peer (`UFW BLOCK ... DPT=14321` and `DPT=14318`). Symptoms:

- Other PC lists this node, but **this Linux box never shows a PIN**
- PIN dialog on the other PC closes, or it says this node is **in another cluster**
- Discovery works; TCP pairing does not

Fix:

```sh
~/.config/omarchy/plugins/io.github.mrdulasolutions.pair/scripts/pair-ctl firewall
```

That opens a terminal for sudo and allows the current LAN CIDR to TCP
`14318-14323` and UDP `5353`. Confirm with:

```sh
journalctl -k -n 50 | grep 'UFW BLOCK' | grep -E '14321|14318'
```

After ports are open:

1. **Settings → Cluster → Leave** on every machine in the attempt.
2. Fully quit and reopen PAIR on macOS if it sat unclustered.
3. One invite, keep the PIN visible until Cluster lists the peer.
4. Do not reuse a PIN from a canceled invite (each Add node mints a new cluster id).

PAIR pairing does **not** require Ollama, a model, or an NVIDIA GPU.

## Checks

```sh
omarchy plugin validate ~/.config/omarchy/plugins/io.github.mrdulasolutions.pair
test -x ~/.local/opt/PAIR/nvpair
ss -ltn | grep -E '11434|1234'   # only after the app is launched
```
