// amy_leaf.h — thin C shim between Rust and AMY.
//
// FFI surface, deliberately tiny and struct-free (verified against
// amy-src/amy.h + amy-src/api.c):
//
//   void     amy_leaf_start(void);          // this shim (amy_leaf.c)
//   void     amy_add_message(char *msg);    // api.c — wire-protocol in
//   uint32_t amy_sysclock(void);            // api.c — ms clock (wraps ~49.7d)
//
// Everything else in the AMY C API is struct-shaped and stays on this side
// of the fence:
//   amy_config_t                — bitfield structs + ~20 function pointers;
//                                 ABI-hostile, so amy_leaf_start() owns
//                                 amy_default_config() + amy_start(cfg).
//   amy_event / amy_default_event / amy_add_event — the wire protocol via
//                                 amy_add_message() expresses the same events
//                                 as text, which is the stable interface.
//   amy_simple_fill_buffer      — not needed: on ESP with multithread=1 AMY
//                                 renders and feeds I2S from its own tasks.
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Configure AMY for the Sonocotta Amped-ESP32-Plus and start it.
// After this returns, AMY owns the I2S peripheral and renders continuously
// on its own FreeRTOS tasks (render on core 0, fill-buffer/I2S on core 1).
// Call exactly once, after esp_idf init.
void amy_leaf_start(void);

#ifdef __cplusplus
}
#endif
