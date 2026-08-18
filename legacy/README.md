# Legacy reference firmware

The proven Arduino/C firmware is **kept as-is** as the known-good baseline. It is *not*
vendored into this repo — it keeps its own Arduino toolchain and lives at:

    /laboratory/esp32-p2p

What's there (all on the same Sonocotta Amped-ESP32-Plus boards):

| Sketch | What it proves |
|---|---|
| `firmware/AmpedAmyMeshStable` | Wi-Fi SoftAP + scale UI + multi-peer AMY token-ring mesh (frozen stable) |
| `firmware/AmpedAmyMeshBleMidi` | the stable mesh + coordinator BLE-MIDI central + UDP MIDI forwarding |
| `firmware/AmpedAmyStandaloneSmoke` | minimal, listener-confirmed AMY audio over I2S — no networking |
| `firmware/AmpedHardwareDiagnostic` | low-level PCM5122 / I2S / amplifier diagnostic |

Libraries there (AMY, NimBLE-Arduino, PCM51xx_DAC) and the bring-up reports
(`reports/`, `docs/bringup-tests.md`) are the reference for board pins, the PCM5122 init
sequence, and the audio path. When the Rust node misbehaves on hardware, flash the matching
legacy sketch to tell a firmware bug from a board/power/wiring problem.

> This repo's `firmware/components/amy` vendors a copy of that AMY source, built as an
> ESP-IDF component. The Arduino AMY (pinned `1.2.108`) stays the reference build.
