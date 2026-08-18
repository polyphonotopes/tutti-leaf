# tutti-leaf tasks. Run `just` to list. All firmware commands run inside firmware/.
# The dev shell (nix develop / direnv) provides espup, espflash, ldproxy, and the
# IDF host deps. `just bootstrap` installs the Xtensa Rust toolchain (one time).

set shell := ["bash", "-uc"]

_default:
    @just --list

# One-time: install the Xtensa `esp` Rust toolchain + LLVM (prebuilt download).
# Safe to re-run; it upgrades in place. Writes ~/export-esp.sh, which the dev
# shell sources on entry.
bootstrap:
    espup install --targets esp32
    @echo "→ Bootstrapped. Re-enter the shell (or: . ~/export-esp.sh) so cargo sees the esp toolchain."

# Debug build for the board.
build:
    cd firmware && cargo build

# Optimized build (what you flash).
release:
    cd firmware && cargo build --release

# Build, flash over USB (CH340), and open the serial monitor. Set PORT to override
# auto-detect, e.g. `just PORT=/dev/tty.usbserial-XXXX flash`.
PORT := ""
flash:
    cd firmware && cargo run --release {{ if PORT != "" { "-- --port " + PORT } else { "" } }}

# Serial monitor only.
monitor:
    espflash monitor {{ if PORT != "" { "--port " + PORT } else { "" } }}

# Wipe the firmware build (does not touch the fetched IDF in ~/.espressif).
clean:
    cd firmware && cargo clean

# Erase the whole flash (recovery).
erase:
    espflash erase-flash {{ if PORT != "" { "--port " + PORT } else { "" } }}
