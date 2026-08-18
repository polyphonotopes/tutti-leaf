# Architecture — one coherent node

A tutti-leaf board is **one ESP-IDF firmware** that binds three things that usually live in
separate worlds:

- **Rust p2p** — the verifiable, eventually-consistent op-DAG (`tutti-core` signed ops,
  `tutti-music` the music language + its lane network identity, `hhhs-dag`'s windowed store,
  `hhhs-sync`'s sans-io RBSR reconciler). This is the *shared* object: what notes are held,
  by whom, in which tuning.
- **AMY** — a fixed-point C synthesizer, compiled as an ESP-IDF component and called from
  Rust over its stable ASCII wire API (`amy_add_message`). This is the *local* performance:
  the actual sound.
- **BLE-MIDI** — an ESP-IDF NimBLE endpoint, so a phone or controller can play the node
  and (later) contribute into the shared object.

Every board runs this same binary and holds its own Ed25519 key, so every board is a full
peer/author. That is the **homogeneous** property: no coordinator, no brain/voice split —
determinism, not consensus.

## The layer stack (one chip)

```
   BLE-MIDI in ──┐                          ┌── ESP-NOW / Wi-Fi (peers)
                 ▼                          ▼
        ┌───────────────────────────────────────────┐
        │ net: transport seam (SyncStream)           │  signed-op bytes in/out
        │   ingress: Ed25519 verify + topic binding  │  (verify once, at ingress)
        ├───────────────────────────────────────────┤
        │ store: hhhs windowed DagRead (W≤256) +     │  "the window is the world"
        │        the small tutti fold                │
        ├───────────────────────────────────────────┤
        │ leaf: Revision{added,retracted} → AMY edge │  diff sounding-set, not replay
        │   playing-notes map · patch compiler ·     │
        │   fail-to-silence watchdog                 │
        ├───────────────────────────────────────────┤
        │ amy_ffi → AMY (C component) → I2S → PCM5122 │  block render, 44.1 kHz fixed-point
        └───────────────────────────────────────────┘
```

Core split, following the leaf design: the protocol side (verify, store, fold, the diff)
runs on one core; AMY renders on the other (its own I2S task). The fold runs at *revision*
rate — an op arrived, refold the window — never at audio-block rate. Nothing musical waits
on the radio: remote structure is scheduled into the next AMY block, not phase-corrected.

## Why AMY is a render target, not an op language

The shared object stays the commuting, mergeable hot-set + facets. AMY's imperative wire
(deltas over receiver state) is a fine *local* language but a lie as a *shared* one — so it
lives only at the edge, inside one device, where it can never race anything. The one
register-shaped slice of AMY (timbre/patch/envelope config) enters the DAG as domain facets,
not raw events. Full reasoning: [`tutti-amy-esp32-leaf.md`](tutti-amy-esp32-leaf.md) §3.

## Transport: ESP-NOW first

The homogeneous mesh wants a peer-to-peer, RAM-cheap, connectionless radio. **ESP-NOW** fits
(no association, mesh-shaped, small frames) and is the first `SyncStream` backend; Wi-Fi UDP
(what the legacy Arduino mesh uses) is the fallback. The `hhhs-sync` driver is sans-io, so a
backend is a framed-duplex adapter, nothing more. Neither iroh nor QUIC is on the chip — the
two-lane design keeps them out of the music-lane path.

## What binds to what

| Concern | Owned by | Notes |
|---|---|---|
| Identity / signing | Rust, key in NVS | one keypair = one author = one channel |
| Shared state (held notes, tuning, timbre facets) | Rust (tutti fold over hhhs window) | the only replicated thing |
| Sound | AMY (C), driven by wire strings | `amy_add_message`; struct never crosses FFI |
| Audio out | AMY's I2S → PCM5122 | board pins BCLK26/WS25/DATA22, amp-enable GPIO13 |
| MIDI in | ESP-IDF NimBLE | drives AMY directly (local) and can promote to ops |
| Peer sync | Rust `hhhs-sync` over ESP-NOW | RBSR; repair + courier for deep laggards |
