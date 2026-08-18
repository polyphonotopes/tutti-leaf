# tutti-leaf

A single ESP32 that is, at once, **a converging p2p peer and a local sound source** —
Rust (the tutti/hhhs verifiable op-DAG) + AMY (a fixed-point C synth) + BLE-MIDI, bound
into one firmware on one chip. Every board runs the same binary and is a full peer: a
**homogeneous synth mesh** where the patch cables are signed ops.

The design rationale lives in [`docs/tutti-amy-esp32-leaf.md`](docs/tutti-amy-esp32-leaf.md);
the shape of this repo is in [`docs/architecture.md`](docs/architecture.md); the order we
bring it up is in [`docs/bring-up.md`](docs/bring-up.md).

## The board

Sonocotta **Amped-ESP32-Plus** — classic dual-core Xtensa LX6 (**ESP32-D0WD-V3**),
8 MB flash + 8 MB PSRAM, PCM5122 I2S DAC + class-D amp, CH340 USB-serial. Target triple
`xtensa-esp32-espidf` (Rust std over ESP-IDF).

## Quickstart (macOS or Linux)

New to Nix / ESP32? [`docs/onboarding.md`](docs/onboarding.md) is a gentle,
step-by-step macOS walk-through. The short version:

You need [Nix](https://nixos.org/download) with flakes. Everything else comes from the
dev shell.

```sh
git clone <this repo> && cd tutti-leaf
nix develop              # or: direnv allow   (auto-enters the shell)
just bootstrap           # one-time: installs the Xtensa Rust toolchain (prebuilt download)
just flash               # build, flash over USB, open the serial monitor
```

`just bootstrap` runs `espup install`. That is a **one-time prebuilt download** of a rustup
toolchain named `esp` — you are *not* building a compiler, and it is native on Apple
Silicon. After it, `cargo` builds for the board like any other target.

> **Xtensa needs the `esp` toolchain.** Classic ESP32 is Xtensa, which uses Espressif's
> Rust fork (the upstream-stable route is RISC-V-only). The fork is a normal rustup
> toolchain; `espup` fetches it. This is the standard, boring path.

### Nix on NixOS / non-FHS Linux

`espup` downloads prebuilt binaries (LLVM, the esp toolchain, IDF tools). On plain macOS
they run as-is. On **NixOS** enable `programs.nix-ld` (or run the bootstrap inside an FHS
shell) so those binaries find their loader. macOS peer devs don't hit this.

## Layout

```
flake.nix            # the dev shell: espup, espflash, ldproxy, IDF host deps (mac + linux)
justfile             # bootstrap / build / flash / monitor / clean
firmware/            # THE node — one ESP-IDF Rust binary for the whole board
  Cargo.toml         #   esp-idf-svc/-hal/-sys + (later) tutti/hhhs p2p
  .cargo/config.toml #   target xtensa-esp32-espidf, build-std, ldproxy, espflash runner
  sdkconfig.defaults #   PSRAM, 8 MB flash, partitions, I2S
  src/               #   main + amy_ffi + audio + net(p2p) + leaf(fold→AMY edge)
  components/amy/    #   AMY vendored as an ESP-IDF component (C), linked into Rust
docs/                # design, architecture, bring-up ladder
legacy/              # pointer to the Arduino/C reference firmware (kept working)
```

## The old experiments still work

The proven Arduino firmware (AMY Wi-Fi token-ring mesh, BLE-MIDI, the audio smoke test,
the hardware diagnostic) is **kept as the reference baseline** and is not touched by this
repo. It lives in `/laboratory/esp32-p2p` with its own Arduino toolchain — see
[`legacy/README.md`](legacy/README.md). When something here misbehaves on the board, that
firmware is the known-good comparison.

## Status

First-pass scaffold. The dev shell + toolchain are wired and the board's "hello, sound"
milestone (AMY tone over I2S) is the first thing that flashes. The p2p stack
(tutti/hhhs) and the fold→AMY edge come in on the ladder in `docs/bring-up.md`. See that
file for exactly what is live vs. stubbed.
