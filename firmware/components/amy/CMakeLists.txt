# AMY synth as an ESP-IDF component.
#
# Vendor the AMY C sources into ./amy-src before building:
#   cp -r /laboratory/esp32-p2p/libraries/AMY/src components/amy/amy-src
#
# The SRCS list below is the MCU core only. Deliberately excluded (desktop /
# web / python / other-MCU support that must not enter the esp32 build):
#   amy-example.c amy-message.c amy-piano.c examples.c   (desktop main()s)
#   libminiaudio-audio.c miniaudio.h                     (desktop audio backend)
#   pyamy.c *.inc *.generated.js amy_connector.js        (python / web bindings)
#   usb.c                                                (tinyusb gadget; S3/AMYboard only —
#                                                         includes tusb.h unconditionally and
#                                                         classic ESP32 has no USB device)
#   macos_midi.m pico_support.cpp teensy_support.cpp pico-audio/ pico_*.cmake
#   *.os                                                 (prebuilt web objects)
#
# amy_midi.c and i2s.c stay in: their tud_* / AMYboard paths are compiled out
# on plain ESP-IDF (guarded by AMYBOARD / TUD_USB_GADGET), and with
# config.midi = AMY_MIDI_IS_NONE run_midi() installs nothing.

set(AMY_SRC amy-src)

idf_component_register(
    SRCS
        "${AMY_SRC}/algorithms.c"
        "${AMY_SRC}/amy.c"
        "${AMY_SRC}/amy_midi.c"
        "${AMY_SRC}/api.c"
        "${AMY_SRC}/custom.c"
        "${AMY_SRC}/cv_trigger.c"
        "${AMY_SRC}/delay.c"
        "${AMY_SRC}/envelope.c"
        "${AMY_SRC}/filters.c"
        "${AMY_SRC}/i2s.c"
        "${AMY_SRC}/instrument.c"
        "${AMY_SRC}/interp_partials.c"
        "${AMY_SRC}/log2_exp2.c"
        "${AMY_SRC}/midi_mappings.c"
        "${AMY_SRC}/oscillators.c"
        "${AMY_SRC}/parse.c"
        "${AMY_SRC}/patches.c"
        "${AMY_SRC}/pcm.c"
        "${AMY_SRC}/sequencer.c"
        "${AMY_SRC}/transfer.c"
        "amy_leaf.c"
    INCLUDE_DIRS "include" "${AMY_SRC}"
    # i2s.c -> driver/i2s_std.h, amy_midi.c -> driver/uart.h,
    # amy.c/i2s.c -> esp_timer.h. heap/freertos/esp_system are common deps.
    REQUIRES driver esp_timer
)

# AMY's build-time knobs. Most AMY configuration in this fork is RUNTIME
# (amy_config_t: osc counts, feature flags, pins, PSRAM caps — set in
# amy_leaf.c), not compile-time. Fixed point (AMY_USE_FIXEDPOINT), 44100 Hz,
# 256-sample blocks, AMY_CORES=2 and the tiny PCM set (pcm_tiny.h) are already
# the amy.h defaults for ESP_PLATFORM; do NOT define GAMMA9001 (that swaps in
# the multi-MB TR-808 PCM bank).
target_compile_definitions(${COMPONENT_LIB} PRIVATE
    AMY_NO_MINIAUDIO=1
)

# ESP-IDF compiles -Os by default; give the render hot path -O2 like the
# Arduino/Alles builds (amy.h also IRAM_ATTRs the hot path on ESP).
target_compile_options(${COMPONENT_LIB} PRIVATE
    -O2
    -Wno-unused-variable
    -Wno-unused-but-set-variable
    -Wno-unused-function
)
