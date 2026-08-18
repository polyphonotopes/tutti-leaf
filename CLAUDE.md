# tutti-leaf — notes for AI assistants

One ESP32 firmware that is both a peer-to-peer node and a local synthesizer:
Rust (the tutti/hhhs verifiable op-DAG) + AMY (a C synth, driven over its wire
API) + BLE-MIDI, on a **classic ESP32** (Xtensa LX6, ESP32-D0WD; Sonocotta
Amped-ESP32-Plus, 8 MB flash + 8 MB PSRAM). Every board runs the same binary and
is a full peer — a homogeneous mesh.

Target triple: **`xtensa-esp32-espidf`** (Rust std over ESP-IDF v5.5.x).

## New to the repo? Read first
`docs/onboarding.md` (setup), `docs/architecture.md` (how it fits together),
`docs/bring-up.md` (the milestone ladder), `docs/tasks.md` (what to work on),
`docs/p2p-integration.md` (the p2p track detail).

## Building and flashing — MUST run inside the Nix dev shell

Interactive (what a human does):
```sh
nix develop            # first-time: also `just bootstrap` (installs the Xtensa toolchain, once)
just build             # compile for the board
just flash             # build + flash over USB + serial monitor (needs a board)
```

Non-interactively (what you, an agent, should run):
- **macOS:** `nix develop --command bash -c 'source ~/export-esp.sh 2>/dev/null; cd firmware && cargo build'`
- **Linux / NixOS:** `nix run .#fhs -- -c 'source ~/export-esp.sh; cd firmware && cargo build'`
  (On NixOS the toolchain is prebuilt binaries that need the FHS wrapper —
  `nix develop --command` and piped stdin do NOT enter it; use `nix run .#fhs`.)

The one-time toolchain install is `just bootstrap` (`espup install --targets esp32`).
It writes `~/export-esp.sh`; the dev shell sources it on entry.

## Hard rules (do not violate)

- **AMY owns the audio hardware.** After `amy_leaf_start()`, never touch the I2S
  peripheral from Rust. Make sound only by sending AMY wire strings via
  `amy_ffi::send("…")` (e.g. `"v0n60l1"` note-on, `"v0l0"` note-off).
- **`amy_config_t` never crosses FFI.** It lives only in
  `firmware/components/amy/amy_leaf.c`. Add/adjust AMY setup there, not in Rust.
- **Project view → AMY, never replay.** When the p2p fold lands (T3), diff the
  *sounding set* and emit note-on/off deltas. Do not push historical ops into
  AMY — its delta pool drops events under bursts.
- **Keep `main` flashable** at every commit.
- **Don't edit `firmware/components/amy/amy-src/`** — it's vendored AMY (MIT,
  see `AMY-LICENSE`). Change behavior through config in `amy_leaf.c`, not by
  patching AMY.

## Known gotchas

- **p2p compile (T3) first hurdle:** `getrandom` needs an esp-idf backend for
  ed25519 entropy. See `docs/p2p-integration.md`.
- **PSRAM:** only 4 MB of the 8 MB chip is memory-mapped on classic ESP32
  (no himem); AMY steers bulk allocations there, per-block buffers stay internal.
- **RAM is tight** — IDF + radio + AMY + the DAG window all compete. Knobs:
  BLE-vs-Wi-Fi, AMY effects off, the sync window size.
- **You cannot fully verify without a board.** A clean `cargo build` proves the
  firmware compiles; the audio/flash behavior is only confirmed by `just flash`
  on hardware. Say so — don't claim on-hardware behavior you didn't observe.

## Dependencies

Currently esp-idf-svc/-hal/-sys + AMY only (the green baseline). The p2p track
adds `tutti-core` / `tutti-music` / `hhhs-sync` (both public:
github.com/polyphonotopes/tutti, gitlab.com/micahscopes/hhhs-rs), pinned by git
rev — bump pins together. The music-lane wire identity comes from `tutti-music`,
so a leaf interoperates without depending on the walkie-songie app.

## Legacy reference

`legacy/README.md` points at the proven Arduino/C firmware (`/laboratory/esp32-p2p`,
Micah's machine) — the known-good AMY audio + BLE-MIDI baseline. It's the
comparison when the board misbehaves; don't port it in wholesale.

## Commits

Imperative mood, technical, concise (e.g. "Add BLE-MIDI note routing to AMY").
Describe what changed and why.
