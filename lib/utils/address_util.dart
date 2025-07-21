String shortenAddress(String address, {int head = 8, int tail = 8}) {
  if (address.length <= head + tail) return address;
  return '${address.substring(0, head)}...${address.substring(address.length - tail)}';
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

bool isBech32(String address) {
  final normalizedAddress = address.toLowerCase();
  return normalizedAddress.startsWith('bc1') ||
      normalizedAddress.startsWith('tb1') ||
      normalizedAddress.startsWith('bcrt1');
}
