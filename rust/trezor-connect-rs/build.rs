//! Build script for protobuf code generation.

use std::io::Result;

fn main() -> Result<()> {
    // Tell cargo to rerun if proto files change
    println!("cargo:rerun-if-changed=proto/");

    // Configure prost to generate code
    let mut config = prost_build::Config::new();

    // Generate BTreeMap for map fields for deterministic serialization
    config.btree_map(["."]);

    // Compile the protobuf files
    config.compile_protos(
        &[
            "proto/messages.proto",
            "proto/messages-common.proto",
            "proto/messages-bitcoin.proto",
            "proto/messages-management.proto",
        ],
        &["proto/"],
    )?;

    Ok(())
}
