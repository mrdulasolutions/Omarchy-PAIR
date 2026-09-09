# NVIDIA PAIR for Omarchy

Install, update, and launch [NVIDIA Personal AI Router (PAIR)](https://github.com/NVIDIA/Personal-AI-Router) on [Omarchy](https://omarchy.org/).

PAIR is **not** NIM, Nemo, or a new inference engine. It is a local router that sits in front of Ollama or LM Studio and can send independent requests to other PAIR nodes on your LAN.

Omarchy is Arch-based. NVIDIA only ships a `.deb`. This plugin extracts that package into `~/.local` so you never need `apt` or `sudo`.

![NVIDIA PAIR panel](preview.png)

## Install the plugin

```sh
omarchy plugin add https://github.com/mrdulasolutions/Omarchy-PAIR.git --enable
```

That clones into
`~/.config/omarchy/plugins/io.github.mrdulasolutions.pair/`
and places a GPU-card icon on the right side of the bar.

**Adding the plugin does not download PAIR.** Omarchy never runs plugin install hooks. Open the panel and click **Install NVIDIA PAIR**, or:

```sh
~/.config/omarchy/plugins/io.github.mrdulasolutions.pair/scripts/pair-ctl install
```

The first download is about 135 MB.

## Usage

| Action | What it does |
| --- | --- |
| Left click | Open the panel |
| Right-click the icon | Install PAIR, or launch it if it is already installed |
| Middle-click the icon | Check GitHub for a newer PAIR app, or update it |
| **Install NVIDIA PAIR** | Download the latest NVIDIA release and unpack it into `~/.local/opt/PAIR` |
| **Launch / Open PAIR** | Start the desktop app, or focus it if it is already running |
| **Check for PAIR updates** | Ask GitHub for the latest `NVIDIA/Personal-AI-Router` release |
| **Update PAIR to …** | Replace the installed app with that newer release |
| Escape | Close the panel |

After PAIR is running, local apps should talk to:

| Engine | Endpoint |
| --- | --- |
| Ollama-compatible | `http://127.0.0.1:11434` |
| OpenAI / LM Studio | `http://127.0.0.1:1234` |

In the PAIR window, install Ollama (default) or LM Studio, add a model, and pair other machines with the six-digit PIN.

## Two different updates

There are two pieces of software. Update them separately.

### 1. This Omarchy plugin (the bar icon and installer)

```sh
omarchy plugin update io.github.mrdulasolutions.pair
```

Or update every git-managed plugin:

```sh
omarchy plugin update
```

That only `git pull`s this repository. It does **not** change the NVIDIA PAIR app.

### 2. The NVIDIA PAIR app

Do **not** use PAIR’s in-app **Settings → Service → Download update** on Omarchy. That updater expects Debian `apt` and `/opt/PAIR`.

Do **not** run `sudo apt install ./NVPAIR-Setup-*.deb`.

Use this plugin instead:

```sh
~/.config/omarchy/plugins/io.github.mrdulasolutions.pair/scripts/pair-ctl update
```

or click **Update PAIR** in the panel.

`pair-ctl update` downloads the latest GitHub release, stops PAIR if it is running, replaces `~/.local/opt/PAIR`, and rewrites the desktop launchers.

To install a specific NVIDIA tag:

```sh
~/.config/omarchy/plugins/io.github.mrdulasolutions.pair/scripts/pair-ctl install --version v0.1.1
```

## What this plugin installs

All user-local, no root:

| Path | Role |
| --- | --- |
| `~/.local/opt/PAIR` | NVIDIA PAIR desktop app and services |
| `~/.local/bin/nvpair-desktop` | GUI launcher (Wayland) |
| `~/.local/bin/nvpair` | Terminal UI (`nvpair-tui`) |
| `~/.local/share/applications/nvpair.desktop` | App menu entry |
| `~/.local/state/omarchy-pair/installed.json` | Version this plugin installed |

Do not run `nvpair` (TUI) while the desktop app is open. They fight over the same ports.

## Hardware notes

PAIR itself does not need an NVIDIA GPU. A node without a GPU can still route requests to machines that have one.

Local inference still needs Ollama or LM Studio plus a model, and enough memory for that model. GeForce RTX 20-series and newer, RTX PRO, DGX Spark, and Apple M4+ are NVIDIA’s validated inference hardware.

## Remove

Remove the plugin (bar icon and installer):

```sh
omarchy plugin remove io.github.mrdulasolutions.pair
```

That does **not** uninstall NVIDIA PAIR. Remove the app with:

```sh
~/.config/omarchy/plugins/io.github.mrdulasolutions.pair/scripts/pair-ctl uninstall
```

Add `--purge` to also delete PAIR cluster identity and settings under
`~/.config/Nvidia Corporation/Personal AI Router`.
Model weights in `~/.ollama` / `~/.lmstudio` are never deleted.

If you already removed the plugin, delete the app by hand:

```sh
rm -rf ~/.local/opt/PAIR
rm -f ~/.local/bin/nvpair ~/.local/bin/nvpair-desktop
rm -f ~/.local/share/applications/nvpair.desktop
```

## Configure

```sh
omarchy bar move io.github.mrdulasolutions.pair --section right
```

## Development

This directory is the live plugin. Saving QML reloads it in `omarchy-shell`.

```sh
omarchy plugin validate ~/.config/omarchy/plugins/io.github.mrdulasolutions.pair
~/.config/omarchy/plugins/io.github.mrdulasolutions.pair/scripts/pair-ctl status --check-latest
omarchy-shell shell rescanPlugins
omarchy-shell shell summon io.github.mrdulasolutions.pair '{}'
```

| File | Role |
| --- | --- |
| `manifest.json` | Plugin contract |
| `Panel.qml` | Bar icon and popup |
| `Model.js` | Status JSON helpers |
| `scripts/pair-ctl` | Install / update / launch NVIDIA PAIR |
| `AGENTS.md` | Instructions for coding agents |

## License

[MIT](LICENSE) for this plugin.

NVIDIA PAIR is a separate project under Apache-2.0.
See [NVIDIA/Personal-AI-Router](https://github.com/NVIDIA/Personal-AI-Router).
