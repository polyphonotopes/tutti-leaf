//! tutti-leaf-fw: "hello, sound" on the Sonocotta Amped-ESP32-Plus.
//!
//! Boot order matters:
//!   1. link_patches + logger (esp-idf-template boilerplate)
//!   2. amp enable high (GPIO13) — otherwise the DAC plays into silence
//!   3. probe the PCM5122 on I2C (SDA 21 / SCL 27) — diagnostic only; the
//!      PCM5122 self-clocks from BCLK via its internal PLL and powers up
//!      unmuted, so first sound needs no register writes
//!   4. amy_leaf_start() — AMY brings up I2S (BCLK 26 / WS 25 / DATA 22)
//!      itself and renders from its own FreeRTOS tasks. Rust must NOT touch
//!      the I2S peripheral after this.
//!   5. speak the wire protocol.

mod amy_ffi;

use std::thread;
use std::time::Duration;

use anyhow::Result;
use esp_idf_hal::delay::BLOCK;
use esp_idf_hal::gpio::PinDriver;
use esp_idf_hal::i2c::{I2cConfig, I2cDriver};
use esp_idf_hal::peripherals::Peripherals;
use esp_idf_hal::units::FromValueType; // .kHz() on integer literals (prelude was removed in hal 0.46)

/// PCM5122 7-bit address with ADR1/ADR2 strapped low.
const PCM5122_ADDR: u8 = 0x4c;

fn main() -> Result<()> {
    // Required once, else some esp-idf-sys runtime patches don't link.
    esp_idf_svc::sys::link_patches();
    esp_idf_svc::log::EspLogger::initialize_default();

    log::info!("tutti-leaf-fw: Amped-ESP32-Plus bring-up");

    let p = Peripherals::take()?;

    // Amp enable. Keep the driver alive for the life of main so the pin
    // isn't reset back to input.
    let mut amp_en = PinDriver::output(p.pins.gpio13)?;
    amp_en.set_high()?;
    log::info!("amp enable (GPIO13) high");

    // PCM5122 control bus. Non-fatal probe: read register 0 (page select)
    // so a wiring/address fault shows up in the log. Keep `i2c` around —
    // volume/format control lives here later.
    let i2c_cfg = I2cConfig::new().baudrate(100u32.kHz().into());
    let mut i2c = I2cDriver::new(p.i2c0, p.pins.gpio21, p.pins.gpio27, &i2c_cfg)?;
    let mut page = [0u8; 1];
    match i2c.write_read(PCM5122_ADDR, &[0x00], &mut page, BLOCK) {
        Ok(()) => log::info!("PCM5122 answered at 0x{PCM5122_ADDR:02x} (page reg {})", page[0]),
        Err(e) => log::warn!("PCM5122 probe failed ({e}); continuing, DAC may still free-run"),
    }

    // Start AMY: spawns render task (core 0) + fill-buffer/I2S task (core 1)
    // and plays its startup bleep — if you hear the bleep, the whole
    // DAC/amp/speaker path works before any wire message is sent.
    amy_ffi::start();
    log::info!("AMY started, sysclock {} ms", amy_ffi::sysclock_ms());

    // Hello, sound: raw osc 0, sine, 220 Hz for a second...
    thread::sleep(Duration::from_millis(500));
    amy_ffi::send("v0w0f220l1");
    thread::sleep(Duration::from_secs(1));
    amy_ffi::send("v0l0");

    // ...then the same osc by MIDI note (60 = middle C).
    thread::sleep(Duration::from_millis(250));
    amy_ffi::send("v0w0n60l1");
    thread::sleep(Duration::from_secs(1));
    amy_ffi::send("v0l0");

    // AMY keeps running on its own tasks; main just idles.
    loop {
        thread::sleep(Duration::from_secs(10));
        log::info!("alive, amy sysclock {} ms", amy_ffi::sysclock_ms());
    }
}
