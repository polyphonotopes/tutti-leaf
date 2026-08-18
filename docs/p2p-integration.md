# p2p integration (T3 + T4)

How the tutti/hhhs stack lands on the board. The design is settled (see
[`tutti-amy-esp32-leaf.md`](tutti-amy-esp32-leaf.md)); this is the concrete
wiring for the firmware.

## Dependencies

The reference minimal set is walkie's `tests/bare-music-peer` crate — a
walkie-free peer that joins a room's music lane. Mirror its deps:

```toml
# firmware/Cargo.toml  (add for T3)
tutti-core  = { git = "https://github.com/polyphonotopes/tutti.git", rev = "7c45571" }
tutti-music = { git = "https://github.com/polyphonotopes/tutti.git", rev = "7c45571" }
hhhs-sync   = { git = "https://gitlab.com/micahscopes/hhhs-rs.git", rev = "82b9ddb", features = ["wire"] }
# hhhs-dag comes in transitively via tutti-core + hhhs-sync.
```

Pins move together (a git rev is part of package identity — a partial bump forks
`EntryHash`). These match walkie/tutti today. The dep set is embedded-friendly:
**blake3 + postcard + ed25519-dalek**, no iroh/QUIC anywhere in the music-lane
path.

## The one real unknown: `getrandom` on esp-idf

ed25519 keygen/signing needs entropy. On `xtensa-esp32-espidf`, `getrandom`
must use the esp-idf backend rather than the `/dev/urandom` default. Options, in
order of preference:

1. `getrandom` already ships an `esp-idf` target path that calls
   `esp_fill_random` — confirm it activates for `xtensa-esp32-espidf` (it keys
   off `target_os = "espidf"`). If it does, nothing to do.
2. If a transitive `getrandom` is too old, pin a newer one, or set the
   `getrandom` custom backend and provide `esp_fill_random`.
3. Worst case, feed a `SigningKey` from an RNG seeded by `esp_random()` at boot.

**This is the first thing T3 should prove** — a build that reaches ed25519 and
signs one op. Everything else in T3 is ordinary porting.

## The fold → AMY edge

Once the store folds, the leaf projects *view changes* into AMY events — never
replays ops. The mapping (leaf doc §3.4, condensed):

| tutti fold output | AMY wire | note |
|---|---|---|
| `Revision.added(degree)` | `v<synth>n<midi_note>l<vel>` | float `midi_note` renders any `.scl` exactly — no MPE |
| `Revision.retracted(degree)` | `v<synth>l0` | edge owns a playing-notes map |
| author → timbre | `v<synth>` index or pan | provenance becomes audible |
| timbre/patch register | `K<patch>` / `u<wire>` | causal register → compiled on change |

Diff the sounding set against what's playing; emit offs for removed, ons for
added. Rate-limit compiled setup (`K`/`u`) messages. Fail-to-silence on a
watchdog. `firmware/src/leaf.rs` owns this; keep the AMY-facing compiler in one
place so an AMY-rev bump touches one file.

## Transport (T4): ESP-NOW

`hhhs-sync`'s driver is sans-io — `drive_initiator` / `drive_responder` take a
framed duplex, nothing more. So a backend is a `SyncStream` adapter:

- **ESP-NOW** is the first target: connectionless, mesh-shaped, small frames,
  RAM-cheap. Frame the RBSR messages (length-prefix or COBS) over ESP-NOW
  unicast; the lane's authenticated identity comes from the signed ops, not the
  MAC.
- Wi-Fi UDP (what the legacy mesh uses) is the fallback if ESP-NOW framing bites.
- Every board advertises the **music lane** only — its ALPN/strategy is
  re-exported from `tutti-music`, so nodes interop without knowing walkie
  exists. This is what makes the mesh homogeneous.

Keep the sync session on one task; never hold a lock across a radio await.

## Milestone shape

T3 = compile + canned fold + sound (one board). T4 = two boards, one RBSR
session, converged music lane. T5 = partition/rejoin, union audible. Each is a
commit; keep `main` flashable at every step.
