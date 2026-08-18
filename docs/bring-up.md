# Bring-up ladder

Cheapest-decisive first. Each rung is independently useful; a rung that slips does not block
the ones below it that don't depend on it. This is the leaf-doc experiment ladder (§7.1)
re-cut for **one classic-ESP32 node** and updated for two facts that changed since that doc:
the **hhhs windowed store (M3) is built**, and the **chip is classic ESP32, not S3**.

| # | Rung | Needs a board? | Depends on |
|---|------|:---:|---|
| 0 | **Toolchain** — `nix develop` + `just bootstrap`; `cargo build` produces an `xtensa-esp32-espidf` ELF. | no (compile only) | — |
| 1 | **Hello, sound** — flash a firmware that starts AMY and plays a tone over I2S/PCM5122. Retires the audio/build risk on the real board. | **yes** | 0 |
| 2 | **BLE-MIDI in** — a controller/phone plays AMY over NimBLE. Parity with the legacy Arduino BleMidi firmware, now in the Rust node. | **yes** | 1 |
| 3 | **p2p core on-chip (offline)** — compile `tutti-core`/`tutti-music`/`hhhs-dag`/`hhhs-sync` for Xtensa; fold a *canned* op-set through the windowed store and drive AMY from the `Revision` diff (the §3.4 edge). No radio yet. | partial (compile is off-board; the fold→sound check wants a board) | 1, and the Xtensa build of the p2p deps |
| 4 | **ESP-NOW transport** — a `SyncStream` backend over ESP-NOW; two boards run one RBSR session and converge their music lane. | **yes (two boards)** | 3 |
| 5 | **Convergence demo** — two nodes, partition one, play into both, rejoin; the union of held pitch-sets becomes audible as it reconciles. First true instance of the mesh. | **yes (two boards)** | 4 |

## Where the risk actually is

1. **Rung 3, the Xtensa build of the p2p deps.** `blake3`, `postcard`, `ed25519-dalek` are
   embedded-friendly, but nobody has compiled the tutti/hhhs stack for `xtensa-esp32-espidf`
   yet. Likely friction: a `getrandom` backend for esp-idf (entropy for signing) and any
   incidental `std` assumptions. This is the first real unknown; it is a compile problem, not
   a design problem.
2. **RAM contention** (IDF + Wi-Fi/BLE stack + AMY + the DAG window). All three have knobs —
   BLE vs Wi-Fi, AMY effects off / PSRAM, the window W. The budget closes on paper (~170–260
   KB of ~300 KB usable internal RAM per the leaf doc §5.3), but classic ESP32 is tighter
   than the S3 that budget assumed; PSRAM is the escape valve.
3. **AMY I2S ownership.** AMY can drive I2S itself, or we hand it a fill buffer. Rung 1 picks
   one and the rest follow.

## Verified vs. needs-a-board

Everything above rung 1 needs the physical board (and, for 4–5, two boards). In this repo,
rung 0's *evaluation* (the flake and the crate config) is checkable off-board; the actual
Xtensa compile and every flash step are the developer's, after `just bootstrap`.
