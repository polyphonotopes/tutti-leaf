// amy_leaf.c — start AMY on the Sonocotta Amped-ESP32-Plus (classic ESP32).
//
// Rust never sees amy_config_t; this file is the only place it exists.

#include "amy.h"
#include "amy_leaf.h"

#include <esp_heap_caps.h>

// Amped-ESP32-Plus I2S wiring to the PCM5122:
//   BCLK GPIO26, LRCK/WS GPIO25, DATA GPIO22, no MCLK routed.
// The PCM5122 PLLs its internal clocks from BCLK, so i2s_mclk stays -1
// (AMY maps that to I2S_GPIO_UNUSED). AMY's own i2s.c drives the port in
// 16-bit Philips stereo at 44100 Hz — exactly what this DAC expects.
#define AMPED_I2S_BCLK 26
#define AMPED_I2S_LRC  25
#define AMPED_I2S_DOUT 22

void amy_leaf_start(void) {
    amy_config_t c = amy_default_config();

    // Lean profile for a 240 MHz dual-LX6 leaf node.
    // (All of this is runtime config in this AMY fork, not compile-time.)
    c.max_oscs = 32;
    c.ks_oscs = 1;
    c.max_voices = 8;
    c.max_synths = 4;
    c.max_memory_patches = 2;
    c.max_sequencer_tags = 32;

    // Effects chain off for now; each of these allocates delay lines and
    // burns render time when enabled.
    c.features.chorus = 0;
    c.features.reverb = 0;
    c.features.echo = 0;
    c.features.partials = 0;
    c.features.custom = 0;
    c.features.audio_in = 0;
    c.features.default_synths = 0;
    // Boot bleep straight from the raw oscs: the cheapest possible
    // "the whole audio path works" smoke test.
    c.features.startup_bleep = 1;

    // Render split across both cores; fill-buffer task owns I2S output.
    c.platform.multicore = 1;
    c.platform.multithread = 1;

    c.audio = AMY_AUDIO_IS_I2S;
    c.midi = AMY_MIDI_IS_NONE; // no UART/USB MIDI on this leaf (yet)

    c.i2s_bclk = AMPED_I2S_BCLK;
    c.i2s_lrc = AMPED_I2S_LRC;
    c.i2s_dout = AMPED_I2S_DOUT;
    c.i2s_din = -1;
    c.i2s_mclk = -1;

    // Steer bulk allocations into the 8 MB PSRAM; keep the per-block render
    // buffers (touched every 256-sample block) in internal RAM.
    c.ram_caps_events = MALLOC_CAP_SPIRAM;
    c.ram_caps_synth = MALLOC_CAP_SPIRAM;
    c.ram_caps_sysex = MALLOC_CAP_SPIRAM;
    c.ram_caps_delay = MALLOC_CAP_SPIRAM;
    c.ram_caps_sample = MALLOC_CAP_SPIRAM;
    c.ram_caps_block = MALLOC_CAP_DEFAULT;
    c.ram_caps_fbl = MALLOC_CAP_DEFAULT;

    amy_start(c);
}
