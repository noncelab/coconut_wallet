import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

String shortenAddress(String address, {int head = 8, int tail = 8}) {
  if (address.length <= head + tail) return address;
  return '${address.substring(0, head)}...${address.substring(address.length - tail)}';
}

class Bip21Data {
  final String address;
  final int? amount;
  final Map<String, String>? parameters;

  Bip21Data({required this.address, this.amount, this.parameters});
}

/// Bip21 주소를 정규화
/// Bech32 (P2WPKH, P2WSH) 주소인 경우 소문자 변환
String normalizeAddress(String input) {
  final address = extractAddressFromBip21(input);
  return isBech32(address) ? address.toLowerCase() : address;
}

String extractAddressFromBip21(String input) {
  if (!input.toLowerCase().startsWith('bitcoin:')) {
    return input;
  }

  final withoutScheme = input.substring(8);

  final queryIndex = withoutScheme.indexOf('?');
  if (queryIndex == -1) {
    return withoutScheme;
  }

  return withoutScheme.substring(0, queryIndex);
}

Bip21Data parseBip21Uri(String input) {
  if (!input.toLowerCase().startsWith('bitcoin:')) {
    return Bip21Data(
      address: input,
      parameters: {},
    );
  }

  final withoutScheme = input.substring(8);
  final queryIndex = withoutScheme.indexOf('?');

  String address;
  Map<String, String> parameters = {};
  int? amount;

  if (queryIndex == -1) {
    address = withoutScheme;
  } else {
    address = withoutScheme.substring(0, queryIndex);
    final queryString = withoutScheme.substring(queryIndex + 1);

    final queryParams = queryString.split('&');
    for (final param in queryParams) {
      final equalIndex = param.indexOf('=');
      if (equalIndex != -1) {
        final key = param.substring(0, equalIndex);
        final value = param.substring(equalIndex + 1);
        parameters[key] = value;

        if (key == 'amount') {
          try {
            final satoshiAmount = double.parse(value);
            amount = (satoshiAmount * 100000000).toInt();
          } catch (e) {
            // amount 파싱 실패 시 무시
          }
        }
      }
    }
  }

  return Bip21Data(
    address: address.toLowerCase(),
    amount: amount,
    parameters: parameters,
  );
}

bool isBech32(String address) {
  final normalizedAddress = address.toLowerCase();
  return normalizedAddress.startsWith('bc1') ||
      normalizedAddress.startsWith('tb1') ||
      normalizedAddress.startsWith('bcrt1');
}

enum AddressValidationError {
  empty,
  minimumLength,
  notTestnetAddress,
  notMainnetAddress,
  notRegtestnetAddress,
  unknown
}

extension AddressValidationErrorMessage on AddressValidationError {
  String get message {
    switch (this) {
      case AddressValidationError.empty:
        return t.errors.address_error.empty;
      case AddressValidationError.notTestnetAddress:
        return t.errors.address_error.not_for_testnet;
      case AddressValidationError.notMainnetAddress:
        return t.errors.address_error.not_for_mainnet;
      case AddressValidationError.notRegtestnetAddress:
        return t.errors.address_error.not_for_regtest;
      case AddressValidationError.minimumLength:
      case AddressValidationError.unknown:
        return t.errors.address_error.invalid;
    }
  }
}

class AddressValidator {
  static AddressValidationError? validateAddress(String address, NetworkType networkType) {
    if (address.isEmpty) {
      return AddressValidationError.empty;
    }

    String normalized = normalizeAddress(address);

    if (normalized.length < 26) {
      return AddressValidationError.minimumLength;
    }

    if (networkType == NetworkType.testnet) {
      if (normalized.startsWith('1') ||
          normalized.startsWith('3') ||
          normalized.startsWith('bc1')) {
        return AddressValidationError.notTestnetAddress;
      }
    } else if (networkType == NetworkType.mainnet) {
      if (normalized.startsWith('m') ||
          normalized.startsWith('n') ||
          normalized.startsWith('2') ||
          normalized.startsWith('tb1')) {
        return AddressValidationError.notMainnetAddress;
      }
    } else if (networkType == NetworkType.regtest) {
      if (!normalized.startsWith('bcrt1')) {
        return AddressValidationError.notRegtestnetAddress;
      }
    }

    try {
      if (!WalletUtility.validateAddress(normalized)) {
        return AddressValidationError.unknown;
      }
    } catch (_) {
      return AddressValidationError.unknown;
    }

    return null;
  }

  /// Bip21 주소를 정규화
  /// Bech32 (P2WPKH, P2WSH) 주소인 경우 소문자 변환
  static String normalizeAddress(String input) {
    final address = extractAddressFromBip21(input);
    return isBech32(address) ? address.toLowerCase() : address;
  }

  static String extractAddressFromBip21(String input) {
    if (!input.toLowerCase().startsWith('bitcoin:')) {
      return input;
    }

    final withoutScheme = input.substring(8);

    final queryIndex = withoutScheme.indexOf('?');
    if (queryIndex == -1) {
      return withoutScheme;
    }

    return withoutScheme.substring(0, queryIndex);
  }

  static bool isBech32(String address) {
    final normalizedAddress = address.toLowerCase();
    return normalizedAddress.startsWith('bc1') ||
        normalizedAddress.startsWith('tb1') ||
        normalizedAddress.startsWith('bcrt1');
  }
}
