# Getting started (macOS)

Welcome. This project turns an ESP32 board into a little networked synthesizer:
it makes sound (via a synth engine called AMY) **and** stays in sync with other
boards peer-to-peer. Your goal for setup is to get it **building on your Mac** —
you don't need a board for that. Flashing a real board comes after.

Nothing here assumes you know Rust, embedded, or Nix. One tool (Nix) installs
everything else, so there's very little to hand-manage.

Works on Apple Silicon (M1/M2/M3/M4) and Intel Macs.

---

## 1. Install Nix (once, ~5 min)

Nix is a package manager that gives everyone the exact same tools. Use the
Determinate Systems installer — it turns on the "flakes" feature we need:

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Then **quit and reopen your terminal**.

## 2. Get the code

Ask Micah to add you to the repo (or he'll make it public), then:

```sh
git clone https://github.com/polyphonotopes/tutti-leaf.git
cd tutti-leaf
```

## 3. Enter the dev shell

```sh
nix develop
```

The first time, this downloads the shared tools (a few minutes). When it's done
your prompt is inside a shell that has everything — you won't install Rust or
ESP32 tools by hand. (Optional: `direnv allow` makes it auto-enter next time.)

Do the remaining steps **inside this shell**.

## 4. Install the ESP32 Rust toolchain (once, ~5–10 min)

```sh
just bootstrap
```

The ESP32's chip (Xtensa) needs Espressif's build of the Rust compiler. This
command downloads it — about 900 MB of **prebuilt** files. You are *not*
compiling a compiler; it's just a download, and it's native on Apple Silicon.

When it finishes, reload the shell so it's picked up:

```sh
exit
nix develop
```

## 5. Build

```sh
just build
```

The first build also downloads ESP-IDF (Espressif's SDK) and builds it, so it
takes a few minutes; after that, builds are quick. **If it finishes without
errors, your setup is correct** — even with no board plugged in.

## 6. Flash a board (only when you have one)

You need a **Sonocotta Amped-ESP32-Plus** and a USB cable (a *data* cable, not a
charge-only one).

- Plug it in. On most recent macOS it just works. If the board isn't detected in
  step below, install the **WCH CH34x macOS driver** (the board's USB-serial
  chip is a CH340) — search "WCH CH34x macOS driver", install, replug.
- Then:

```sh
just flash
```

This builds, uploads to the board, and opens a live log. You should hear a short
**startup bleep**, then two test tones, and see log lines. Press `Ctrl-C` to
leave the monitor.

If `just flash` can't find the port, list them with `ls /dev/tty.*` (it'll be
something like `/dev/tty.wchusbserial…`) and pass it:
`just PORT=/dev/tty.wchusbserial1420 flash`.

---

## Where to work

- **`docs/tasks.md`** — the task board. Two independent tracks are ready to grab:
  **BLE-MIDI** (play the synth from a MIDI keyboard/phone) and **p2p on-chip**
  (get the peer-to-peer sync compiling on the board). Pick one.
- **`docs/architecture.md`** — how the pieces fit (Rust + AMY + BLE-MIDI in one
  firmware).
- **`docs/bring-up.md`** — the step ladder we're climbing.
- **`docs/p2p-integration.md`** — the deep details for the p2p track.
- **`docs/tutti-amy-esp32-leaf.md`** — the long "why" (optional, deep reading).

## Using your Claude Code agent here

There's a **`CLAUDE.md`** at the repo root written for your agent — it has the
build/flash commands, the target chip, and the "don't do this" list (e.g. AMY
owns the audio hardware; never drive it directly from Rust). Your agent reads
that automatically. If you get stuck, paste the exact error to it, or to Micah.

## Quick troubleshooting

| Symptom | Fix |
|---|---|
| Board not detected | Install the WCH CH34x mac driver; try another (data) cable/port |
| `just build` fails right after bootstrap | `exit`, `nix develop` again (reloads the toolchain), rebuild |
| "command not found: just / cargo" | You're outside the shell — run `nix develop` first |
| Build downloads a lot the first time | Normal: ESP-IDF + toolchain are one-time |
