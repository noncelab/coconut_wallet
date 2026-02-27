# Coconut Wallet

[![GitHub tag](https://img.shields.io/badge/dynamic/yaml.svg?url=https://raw.githubusercontent.com/noncelab/coconut_wallet/main/pubspec.yaml&query=$.version&label=Version)](https://github.com/noncelab/coconut_wallet)
[![License](https://img.shields.io/badge/License-X11-green.svg)](https://github.com/noncelab/coconut_wallet/blob/main/LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.29-blue?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey)](https://github.com/noncelab/coconut_wallet)

<p align="center">
  <img src="./assets/readme/wallet.png" alt="Coconut Wallet Logo" width="96"/>
</p>

<p align="center">
  <a href="https://apps.apple.com/kr/app/%EC%BD%94%EC%BD%94%EB%84%9B-%EC%9B%94%EB%A0%9B-%EB%B9%84%ED%8A%B8%EC%BD%94%EC%9D%B8-%EC%A7%80%EA%B0%91/id6745778545"><img src="./assets/readme/app-store-badge.png" alt="App Store" height="40"/></a>&nbsp;&nbsp;
  <a href="https://play.google.com/store/apps/details?id=onl.coconut.wallet"><img src="./assets/readme/google-play-badge.png" alt="Google Play" height="40"/></a>
</p>

<p align="center">
  Watch-only Bitcoin Wallet for iOS & Android
</p>


> **Try it risk-free!** A **regtest version** is available on both app stores, allowing you to practice air-gapped transactions with test bitcoin — no real funds required.</br>
> [App Store](https://apps.apple.com/app/id6654902298) · [Google Play](https://play.google.com/store/apps/details?id=onl.coconut.wallet.regtest)

---

**Coconut Wallet** is a **watch-only Bitcoin wallet** designed to work with [Coconut Vault](https://github.com/noncelab/coconut_vault). By operating the vault and wallet on two physically separate devices, it implements a **secure air-gapped transaction signing architecture** where private keys never touch an online device.

## Features

No hot wallet. Watch-only only.

- **Supported hardware wallets** — Keystone 3 Pro, Seedsigner, Jade, Coldcard, Krux
- **Air-gapped signing** — Private keys never leave the offline device
- **SegWit** — Native SegWit (Bech32) address support
- **Multisig** — Multi-signature wallet support
- **RBF (Replace-By-Fee)** — Fee bumping for unconfirmed transactions
- **CPFP (Child-Pays-For-Parent)** — Fee acceleration via child transactions
- **Batch sending** — Send to multiple recipients in a single transaction
- **UTXO management** — Coin control with UTXO locking and tagging
- **PSBT** — BIP-174 Partially Signed Bitcoin Transactions
- **Draft transactions** — Save transactions as drafts for later signing or sending
- **Multilingual** — 한국어, English, 日本語, Español

## Architecture

```
      OFFLINE                                        ONLINE
┌─────────────────┐          QR Code         ┌─────────────────┐
│  Coconut Vault  │ ◄──────────────────────► │ Coconut Wallet  │
│                 │                          │                 │
│  · Key storage  │                          │  · Balance sync │
│  · Tx signing   │                          │  · Tx creation  │
│                 │                          │  · Broadcasting │
└─────────────────┘                          └─────────────────┘
```

The wallet stays online to keep your wallet data up to date and broadcasts signed transactions to the Bitcoin network.

## Coconut Projects

| Project | Description |
|---------|-------------|
| [coconut_lib](https://pub.dartlang.org/packages/coconut_lib) | [![pub](https://img.shields.io/pub/v/coconut_lib.svg?label=coconut_lib&color=blue)](https://pub.dartlang.org/packages/coconut_lib) — Bitcoin wallet development library |
| [coconut_vault](https://github.com/noncelab/coconut_vault) | [![tag](https://img.shields.io/badge/dynamic/yaml.svg?url=https://raw.githubusercontent.com/noncelab/coconut_vault/main/pubspec.yaml&query=$.version&label=coconut_vault)](https://github.com/noncelab/coconut_vault) — Offline signer |
| [coconut_wallet](https://github.com/noncelab/coconut_wallet) | [![tag](https://img.shields.io/badge/dynamic/yaml.svg?url=https://raw.githubusercontent.com/noncelab/coconut_wallet/main/pubspec.yaml&query=$.version&label=coconut_wallet)](https://github.com/noncelab/coconut_wallet) — Watch-only wallet |
| [coconut_design_system](https://github.com/noncelab/coconut_design_system) | [![tag](https://img.shields.io/badge/dynamic/yaml.svg?url=https://raw.githubusercontent.com/noncelab/coconut_design_system/main/pubspec.yaml&query=$.version&label=coconut_wallet)](https://github.com/noncelab/coconut_wallet) — Design System |

## Build & Run

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.29+)
- Dart 3.7+
- Android Studio or Xcode

```bash
flutter --version
```

### Clone & Install Dependencies

```bash
git clone https://github.com/noncelab/coconut_wallet.git
cd coconut_wallet
flutter pub get
```

### Code Generation

```bash
dart run build_runner build --delete-conflicting-outputs
dart run realm generate
flutter pub run slang
```

> If Realm generation fails, run `dart run build_runner clean` first.

### Environment Variables

This project requires environment variables configured via `flutter_dotenv`. To obtain the env file for development, please contact us at [hello@noncelab.com](mailto:hello@noncelab.com).

### Android Keystore Setup

Generate a local keystore for Android builds:

```bash
keytool -genkey -v -keystore android/app/local.jks \
  -storepass android -alias local -keypass android \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Local Dev,O=Coconut,C=KR"
```

Create `key_regtest.properties` and `key_mainnet.properties` under the `android/` directory:

```properties
storePassword=android
keyPassword=android
keyAlias=local
storeFile=../app/local.jks
```

### Run

```bash
# Debug
flutter run --flavor regtest

# Release
flutter run --release --flavor regtest
```

### Flavors

| Flavor | Description |
|--------|-------------|
| `mainnet` | Real Bitcoin mainnet — production release distributed via app stores |
| `regtest` | Local testnet — for learning and development |

### IDE Configuration

**Android Studio / IntelliJ**

Run → Edit Configurations... → Set Build Flavor to `regtest`

**VS Code** — `.vscode/launch.json`:

```json
{
  "name": "coconut_wallet (debug)",
  "request": "launch",
  "type": "dart",
  "args": ["--flavor", "regtest"]
}
```

> **⚠️ Mainnet Self-Build Disclaimer**: If you build and run the app from source on mainnet outside of official distribution channels (App Store / Google Play), we assume no responsibility for any loss of funds or errors that may occur. Please use `regtest` mode for development and testing.

## Contributing

Please refer to [CONTRIBUTING.md](https://github.com/noncelab/coconut_wallet/blob/main/CONTRIBUTING.md) for details.

- [Issues](https://github.com/noncelab/coconut_wallet/issues) — Bug reports and feature requests
- [Pull Requests](https://github.com/noncelab/coconut_wallet/pulls) — New features, documentation improvements, and bug fixes

## Responsible Disclosure

If you discover a critical security vulnerability, please report it directly to [hello@noncelab.com](mailto:hello@noncelab.com) instead of opening a public issue.

## License

X11 Consortium License (identical to MIT, with an additional restriction that the copyright holder's name may not be used for promotional purposes).

See [LICENSE](https://github.com/noncelab/coconut_wallet/blob/main/LICENSE) for details.

### Dependencies

All third-party libraries used in this project are licensed under MIT, BSD, or Apache. See the [full list](https://github.com/noncelab/coconut_wallet/blob/main/lib/oss_licenses.dart) for details.

## Community & Links

| | |
|---|---|
| **Website** | [coconut.onl](https://coconut.onl) / [powbitcoiner.com](https://https://powbitcoiner.com)|
| **X (Twitter)** | [@CoconutWallet 🌐](https://x.com/CoconutWallet) / [@Coconut 🇰🇷](https://x.com/Coconut_BTC) |
| **Discord** | [Join our Discord](https://discord.gg/VjZxYaQCRj) |
| **Documentation** | [Tutorials & Docs](https://tutorial.coconut.onl) |
| **GitHub** | [github.com/noncelab](https://github.com/noncelab) |
| **Company Site** | [NonceLab](https://noncelab.com) |


</br>
<img src="./assets/readme/coconut-logo.png" alt="Coconut Logo" width="320"/>