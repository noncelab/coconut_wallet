// Re-export everything from bark-ffi
// Note: The actual library with UniFFI metadata used for binding generation
// is bark-ffi itself (from target/release/deps), not this wrapper.
// This wrapper is only used at runtime by Dart's native assets system.
pub use bark_ffi::*;

/// COCONUT PATCH: send bark's `log` records to Android logcat (tag `bark`).
///
/// bark-ffi's only log sink is `set_logger`, which calls a foreign callback synchronously on
/// whichever thread logs (usually a tokio worker). The Dart bindings implement that callback with
/// `Pointer.fromFunction`, which may only run on the isolate's thread, so the SDK's own
/// `barkAttachPrintLogger()` aborts the process on the first log record. Logging straight to
/// logcat from Rust is safe on any thread. Installed when the library is loaded, Android only;
/// don't also call `setLogger` (the `log` crate accepts one logger per process).
#[cfg(target_os = "android")]
mod logcat {
    use std::ffi::CString;
    use std::os::raw::{c_char, c_int};

    #[link(name = "log")]
    extern "C" {
        fn __android_log_write(prio: c_int, tag: *const c_char, text: *const c_char) -> c_int;
    }

    /// Crates logged at debug level; everything else (tonic, hyper, rustls…) at info.
    const DEBUG_TARGETS: &[&str] = &["bark", "bark_ffi", "ark", "server_rpc", "bitcoin_ext"];

    struct Logcat;

    impl log::Log for Logcat {
        fn enabled(&self, metadata: &log::Metadata) -> bool {
            let target = metadata.target();
            let crate_name = target.split("::").next().unwrap_or(target);
            let max = if DEBUG_TARGETS.contains(&crate_name) { log::Level::Debug } else { log::Level::Info };
            metadata.level() <= max
        }

        fn log(&self, record: &log::Record) {
            if !self.enabled(record.metadata()) {
                return;
            }
            let prio = match record.level() {
                log::Level::Error => 6,
                log::Level::Warn => 5,
                log::Level::Info => 4,
                log::Level::Debug => 3,
                log::Level::Trace => 2,
            };
            write(prio, &format!("[{}] {}", record.target(), record.args()));
        }

        fn flush(&self) {}
    }

    fn write(prio: c_int, message: &str) {
        let tag = c"bark";
        if let Ok(text) = CString::new(message.replace('\0', "")) {
            unsafe { __android_log_write(prio, tag.as_ptr(), text.as_ptr()) };
        }
    }

    static LOGGER: Logcat = Logcat;

    extern "C" fn install() {
        if log::set_logger(&LOGGER).is_ok() {
            log::set_max_level(log::LevelFilter::Debug);
        }
        let default_hook = std::panic::take_hook();
        std::panic::set_hook(Box::new(move |info| {
            write(6, &format!("panic: {info}"));
            default_hook(info);
        }));
    }

    #[used]
    #[link_section = ".init_array"]
    static INSTALL: extern "C" fn() = install;
}
