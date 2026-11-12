# Bark Dart SDK

Integrate fast, low-cost, scalable Bitcoin payments into your Flutter/Dart apps with the Bark Dart SDK. Combine on-chain, Ark and Lightning Network payments with one simple integration, no channel management and fully self-custodial.

## Overview

This package provides Dart bindings for [bark](https://gitlab.com/ark-bitcoin/bark), an implementation of the Ark protocol on Bitcoin led by [Second](https://second.tech). These bindings allow Dart and Flutter applications to integrate Ark wallet functionality, enabling instant, low-cost Bitcoin payments via the Ark protocol without losing custody of funds.

Bark enables:

- 🏃‍♂️ **Instant onboarding**: No channels to open, start transacting immediately
- 🤌 **Simplified UX**: Send and receive without managing channels or liquidity
- 🌐 **Universal payments**: Send Ark, Lightning, and on-chain payments
- 💸 **Lower costs**: Instant payments at a fraction of on-chain fees
- 🔒 **Self-custodial**: Full control of your funds at all times

## Installation

### Requirements

- Dart SDK ≥ 3.10.0 (for Native Assets support)
- Rust toolchain (cargo, rustc) for building native library
- Flutter 3.x+ (for Flutter apps)

### Add to your project

**Via pub.dev:**

```yaml
dependencies:
  bark_bitcoin: ^0.25.0+bark-0.7.1
```

**Via git (for latest development or specific versions):**

```yaml
dependencies:
  bark_bitcoin:
    git:
      url: https://gitlab.com/ark-bitcoin/bark-ffi-bindings
      path: dart/
      ref: v0.25.0+bark-0.7.1 # or specific tag
```

Then run:

```bash
dart pub get  # or flutter pub get
```

The native library will be automatically built by Dart's Native Assets system when you run your app.

### Beta/Pre-release Versions

To use a beta or pre-release version:

```yaml
dependencies:
  bark_bitcoin:
    git:
      url: https://gitlab.com/ark-bitcoin/bark-ffi-bindings
      path: dart/
      ref: v0.25.0+bark-0.7.1 # Specific version tag
```

## Usage

### Create a new wallet

```dart
import 'package:bark_bitcoin/bark_bitcoin.dart';

// Configure for signet
final config = Config(
  'https://ark.signet.2nd.dev',
  'https://esplora.signet.2nd.dev',
  Network.signet,
  null,  // vtxoRefreshExpiryThreshold - use defaults
  null,  // vtxoExitMargin - use defaults
  null,  // htlcRecvClaimDelta - use defaults
);

// Create wallet with BIP39 mnemonic
final wallet = Wallet.create(
  'your twelve word mnemonic phrase goes here today',
  config,
  '/path/to/wallet/data',
  false,  // forceRescan
);

print('Wallet fingerprint: ${wallet.properties().fingerprint}');
```

### Open existing wallet

```dart
final wallet = Wallet.open(
  'your twelve word mnemonic phrase goes here today',
  config,
  '/path/to/wallet/data',
);
```

### Sync and check balance

```dart
// Lightweight sync
wallet.sync_();

// Get balance
final balance = wallet.balance();
print('Spendable: ${balance.spendableSats} sats');
print('Pending in round: ${balance.pendingInRoundSats} sats');
print('Pending exit: ${balance.pendingExitSats} sats');
```

### Receive payments

```dart
// Generate Ark address
final arkAddress = wallet.newAddress();
print('Send funds to: $arkAddress');

// Or create a Lightning invoice
final invoice = wallet.bolt11Invoice(10000);
print('Lightning invoice: ${invoice.invoice}');
```

### Send payments

```dart
// Pay Lightning invoice
try {
  final result = wallet.payLightningInvoice('lnbc...', null);
  print('Payment successful! Preimage: ${result.preimage}');
} on BarkError catch (e) {
  print('Payment failed: $e');
}

// Pay to Lightning Address
final result = wallet.payLightningAddress(
  'user@domain.com',
  5000,
  'Coffee payment',
);

// Send to Ark address (instant, out-of-round)
wallet.sendArkoorPayment('ark1...', 1000);
```

### Claim Lightning receives

```dart
// Claim all pending Lightning receives
wallet.tryClaimAllLightningReceives(true);
```

### Offboard to on-chain

```dart
// Offboard all funds to Bitcoin address
final result = wallet.offboardAll('bc1q...');
print('Offboarded in round: ${result.roundId}');
```

### Maintenance

```dart
// Full maintenance (recommended periodic operation)
wallet.maintenance();
```

## Error Handling

The package uses typed errors via `BarkError`:

```dart
try {
  wallet.payLightningInvoice('lnbc...', null);
} on BarkError catch (e) {
  switch (e) {
    case BarkError_InsufficientFunds():
      print('Not enough balance');
    case BarkError_InvalidInvoice():
      print('Invalid invoice format');
    case BarkError_ServerConnection():
      print('Cannot connect to server');
    default:
      print('Error: $e');
  }
}
```

## Example

### Pure Dart Example

See [example/main.dart](example/main.dart) for a pure Dart example demonstrating how to also use a default onchain wallet or how to integrate your own existing onchain wallet for on- and offboarding operations.

To run the example:

```bash
dart run example/main.dart
```

### Flutter App Example

See [example/flutter_app](example/flutter_app) for a Flutter app example integrating the Bark Dart SDK.

## Development

### For Package Maintainers

⚠️ **The following instructions are for bark package maintainers only.**
End users of the bark package do not need to build from source or run the generator script.

#### Generating bindings after changes

When `bark-ffi` is modified, the Dart bindings must be regenerated to reflect the changes.

1. Copy the updated UDL file from [bark-ffi](https://gitlab.com/ark-bitcoin/bark-ffi) to [rust/src/bark.udl](rust/src/bark.udl). For the build hook and bindgen script to work with [uniffi-dart](https://github.com/uniffi-dart/uniffi-dart), we need it in this location.

2. Run the bindings generator script:

   From the `dart/` directory, run:

   ```bash
   bash ./generate-bindings.sh
   ```

   or from the root of the repository, you can also run:

   ```bash
   make dart
   ```

   This script:
   - Builds bark-ffi from the workspace
   - Generates Dart bindings into `lib/bark.dart`

3. Test the generated bindings:

   ```bash
   cd ..
   dart pub get
   dart test
   ```

4. Commit the changes and generated files:
   ```bash
   git add .
   git commit -m "chore: update Dart bindings"
   ```

### For End Users

End users installing bark **do not** need to run `generate-bindings.sh`.

When you add bark as a dependency and run your app, Dart's Native Assets system automatically:

1. Finds the Rust source in the `rust/` directory
2. Compiles it for your platform
3. Links it to your Dart/Flutter application

You only need:

- Dart SDK ≥ 3.10.0
- Rust toolchain (cargo, rustc) installed on your system: run `rustup install stable` if you don't have it yet.

## Documentation

- [Bark Documentation](https://second.tech/docs)
- [Getting Started on Signet](https://second.tech/docs/getting-started/bark-cli/signet)
- [Ark Protocol](https://second.tech/docs/learn/intro)
- [Dart Native Assets Hooks](https://dart.dev/tools/hooks)

## License

CC0-1.0 - See [LICENSE](../../LICENSE) for details.

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for contribution guidelines.

## Support

- [Community Forum](https://chat.second.tech)
- [GitLab Issues](https://gitlab.com/ark-bitcoin/bark-ffi-bindings/-/issues)
- [Website](https://second.tech)
