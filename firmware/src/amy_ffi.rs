//! Hand-written FFI to the AMY component (components/amy).
//!
//! Deliberately not bindgen: the only symbols Rust needs are three flat C
//! functions. `amy_config_t` (nested bitfield structs plus ~20 function
//! pointers) never crosses the boundary — `amy_leaf_start()` in
//! components/amy/amy_leaf.c owns it, so AMY struct-layout churn can't
//! silently break the Rust side.

use std::os::raw::c_char;

extern "C" {
    /// components/amy/amy_leaf.c — amy_default_config() + Amped-Plus pins +
    /// lean settings + amy_start(). Spawns AMY's FreeRTOS tasks; AMY owns
    /// I2S from then on.
    fn amy_leaf_start();

    /// api.c — parse and schedule a wire-protocol message (e.g. "v0w0f220l1").
    /// The parser may scribble on the buffer (it takes `char *`), and it does
    /// not retain the pointer past the call.
    fn amy_add_message(message: *mut c_char);

    /// api.c — AMY's millisecond clock (u32, wraps every ~49.7 days).
    fn amy_sysclock() -> u32;
}

/// Start AMY. Call exactly once from the main task, after `link_patches()`.
pub fn start() {
    unsafe { amy_leaf_start() }
}

/// Send an AMY wire message, e.g. `"v0w0f220l1"` (osc 0, sine, 220 Hz, note on)
/// or `"v0l0"` (note off).
///
/// The message is copied into an owned, NUL-terminated buffer because
/// `amy_add_message` takes `char *` and may mutate it in place while parsing.
/// (Not `CString::into_raw`/`from_raw`: a parser-written interior NUL would
/// make `from_raw` reconstruct the wrong allocation length.)
pub fn send(msg: &str) {
    assert!(
        !msg.as_bytes().contains(&0),
        "AMY wire message must not contain NUL"
    );
    let mut buf = Vec::with_capacity(msg.len() + 1);
    buf.extend_from_slice(msg.as_bytes());
    buf.push(0);
    unsafe { amy_add_message(buf.as_mut_ptr() as *mut c_char) };
    // buf drops here; AMY has already turned it into queued deltas.
}

/// AMY's millisecond sysclock (sample-clock derived).
pub fn sysclock_ms() -> u32 {
    unsafe { amy_sysclock() }
}
