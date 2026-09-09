# Agent notes: NVIDIA PAIR on Omarchy

You are installing or updating **NVIDIA Personal AI Router (PAIR)** on Omarchy Linux.

This is **not** NVIDIA NIM, NeMo, TensorRT-LLM, or a new inference engine.
PAIR is a local router in front of Ollama / LM Studio.
Official project: https://github.com/NVIDIA/Personal-AI-Router

Omarchy is Arch-based (`ID_LIKE=arch`). NVIDIA’s Linux installer is a `.deb`.
**Never** `apt install` that package here. **Never** `sudo` for this plugin.

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

- PAIR window: first-run can install Ollama (default) or LM Studio.
- Apps should use `http://127.0.0.1:11434` (Ollama) or `http://127.0.0.1:1234` (OpenAI).
- Pairing other PCs uses a six-digit PIN on the same LAN.
- A machine without an NVIDIA GPU can still run PAIR as a router node.

## Checks

```sh
omarchy plugin validate ~/.config/omarchy/plugins/io.github.mrdulasolutions.pair
test -x ~/.local/opt/PAIR/nvpair
ss -ltn | grep -E '11434|1234'   # only after the app is launched
```
