# Task board

Grabbable tracks for a collab session. Each is scoped to a rung in
[`bring-up.md`](bring-up.md), names the files it touches, and states when it's
done. T2 and T3 are independent — two people can take them in parallel.

## In flight

- **T1 · Green baseline + hello-sound** — first `cargo build` for
  `xtensa-esp32-espidf`, then flash and confirm the AMY startup bleep + the two
  test tones on a board.
  Files: `firmware/` (already scaffolded). Done when: `just flash` boots the
  Amped+ and you hear it. *(owner: setup)*

## Ready to grab

- **T2 · BLE-MIDI in** — a controller/phone plays AMY over BLE-MIDI.
  Approach: ESP-IDF NimBLE MIDI service; on note-on/off, emit the AMY wire
  string (`v<osc>n<note>l<vel>` / `l0`) via `amy_ffi::send`. The legacy
  `AmpedAmyMeshBleMidi` sketch (see [`../legacy/README.md`](../legacy/README.md))
  is the reference for the BLE-MIDI plumbing.
  Files (new): `firmware/src/midi.rs`. Config: NimBLE via `esp-idf-svc`.
  Done when: a BLE-MIDI keyboard plays notes through the DAC.
  *Depends on: T1. Independent of T3/T4.* Good fit for whoever did the Arduino
  BLE-MIDI work.

- **T3 · p2p core on-chip (offline)** — compile `tutti-core` + `tutti-music` +
  `hhhs-dag` + `hhhs-sync` for Xtensa, fold a *canned* op-set through the
  windowed store, and drive AMY from the `Revision` diff. No radio yet.
  This is the first real unknown (see [`p2p-integration.md`](p2p-integration.md)):
  the likely friction is a `getrandom` backend for esp-idf and any incidental
  `std` assumption. It is a compile problem, not a design problem.
  Files (new): `firmware/src/leaf.rs`; add the p2p deps to `firmware/Cargo.toml`.
  Done when: a fixed op-set produces the expected notes on the board.
  *Depends on: T1.*

## Queued (need T3, and two boards)

- **T4 · ESP-NOW transport** — a `SyncStream` backend over ESP-NOW; two boards
  run one RBSR session and converge their music lane.
  Files (new): `firmware/src/net.rs`. See `p2p-integration.md` §transport.
- **T5 · Convergence demo** — two nodes, partition one, play into both, rejoin;
  hear the union of held pitch-sets reconcile. The first real instance of the
  mesh.

## Known gotchas (save everyone the surprise)

- **AMY owns I2S.** After `amy_leaf_start()`, never touch the I2S peripheral
  from Rust. Drive AMY only through wire strings.
- **`getrandom` on esp-idf.** ed25519 signing needs entropy; wire
  `getrandom`'s esp-idf path (or `esp_fill_random`) — see `p2p-integration.md`.
- **PSRAM: only 4 MB of 8 is mapped** on classic ESP32 without himem. Steer bulk
  allocs to PSRAM (AMY already does); keep per-block buffers internal.
- **RAM is tighter than the S3 budget** the leaf doc assumed. Watch the
  IDF+radio+AMY+DAG-window total; knobs are BLE-vs-Wi-Fi, AMY effects off, and
  the window size W.
- **The fold runs at revision rate, never per audio block.** Diff the sounding
  set; do not replay history into AMY (its delta pool drops under storms).
