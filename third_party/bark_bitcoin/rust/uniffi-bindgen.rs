fn main() {
    use camino::Utf8Path;

    let args: Vec<String> = std::env::args().collect();

    let library_path = args
        .iter()
        .find_map(|arg| {
            if !arg.starts_with("--")
                && (arg.ends_with(".dylib") || arg.ends_with(".so") || arg.ends_with(".dll"))
            {
                Some(arg.clone())
            } else {
                None
            }
        })
        .expect("Library path not found - specify a .dylib, .so, or .dll file");

    let output_dir = args
        .iter()
        .position(|arg| arg == "--out-dir")
        .and_then(|idx| args.get(idx + 1))
        .expect("--out-dir is required");

    // Get absolute path to uniffi.toml
    let current_dir = std::env::current_dir().expect("Failed to get current directory");
    let config_path_abs = current_dir.join("uniffi.toml");
    let config_path = Utf8Path::from_path(&config_path_abs).expect("Invalid UTF-8 in path");

    let library_path = Utf8Path::new(library_path.as_str());
    let out_dir = Utf8Path::new(output_dir.as_str());

    // Generate bindings using library mode
    // The library has embedded UniFFI metadata and UDL will be auto-located from bark-ffi's source
    uniffi_dart::gen::generate_dart_bindings(
        library_path,       // Not used in library mode, but required by API
        Some(config_path),  // Config file with Dart-specific settings
        Some(out_dir),      // Output directory
        library_path,       // Library file with embedded metadata
        true,               // library_mode = true (auto-locate UDL from dependencies)
    )
    .expect("Failed to generate dart bindings");
}
