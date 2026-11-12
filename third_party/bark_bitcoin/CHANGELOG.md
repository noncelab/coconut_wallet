# Changelog

All notable changes to the bark_bitcoin Dart package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2-beta.32+bark.0.1.0-beta.8] - 2026-03-10

### Added
- `estimateSendOnchainFee` method on Wallet

### Fixed
- Fixed missing FfiConverterSequenceDestination and FfiConverterOptionalBlockRef in generated bindings
- Switched to patched uniffi-dart fork that correctly generates converters for Sequence/Optional of custom record types in callback interfaces

## [0.1.1-beta.1+bark.0.1.0-beta.7] - 2026-02-17

### Changed
- Renamed package from `bark` to `bark_bitcoin` to avoid conflict with existing pub.dev package
- Updated to bark-ffi v0.1.0-beta.7

### Added
- Initial beta release of Dart bindings for Bark (Ark on Bitcoin)
- Support for wallet creation and management
- Support for VTXOs (Virtual UTXOs)
- Support for on-chain and off-chain transactions
- BOLT11 invoice generation
- Native Assets integration for automatic library building

## [Unreleased]

- First public release
