import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/logger.dart';

class DescriptorUtil {
  static const String allowedDescriptorFunction = 'wpkh';
  static const _fingerprint = r"[0-9a-fA-F]{8}";
  static const _purposeCoin = r"/84(?:'|h)/(?:1|0)(?:'|h)";
  static const _account = r"/\d+(?:'|h)";
  static const _xpubPrefix = r"(tpub|vpub|xpub|zpub)";
  static const _base58 = r"[1-9A-HJ-NP-Za-km-z]{107,108}";

  static const _basePath = "$_fingerprint$_purposeCoin$_account";

  static String? getDescriptorFunction(String descriptor) {
    final match = RegExp(r'^(wpkh|wsh|sh|pkh|multi|sortedmulti|tr)\(').firstMatch(descriptor);
    return match?.group(1);
  }

  static String wrapWithDescriptorFunction(String descriptor) {
    // Invalid Descriptor Function인 경우 처리를 막는다. ex: invalid(~)
    if (descriptor.contains("(") || descriptor.contains(")")) {
      Logger.log('Invalid descriptor function: $descriptor');
      throw FormatException('Invalid descriptor function: $descriptor');
    }

    return '$allowedDescriptorFunction($descriptor)';
  }

  static String extractPurpose(String descriptor) {
    // wpkh(...) 같은 wrapper 제거
    final innerDescriptor = getDescriptorFunction(descriptor) != null
        ? descriptor.substring(descriptor.indexOf('(') + 1, descriptor.lastIndexOf(')'))
        : descriptor;

    // 대괄호 [fingerprint/derivationPath] 추출
    final startIndex = innerDescriptor.indexOf('[');
    final endIndex = innerDescriptor.indexOf(']');

    if (startIndex == -1 || endIndex == -1) {
      throw const FormatException('Invalid descriptor format: missing square brackets');
    }

    final squareBracket = innerDescriptor.substring(startIndex + 1, endIndex);

    final path = squareBracket.split('/');

    if (path.isEmpty || path.length < 2) {
      throw const FormatException('Invalid descriptor format');
    }

    final purposeWithHardenedMark = path[1];
    return purposeWithHardenedMark;
  }

  static void validatePurpose(String purpose) {
    if (purpose != "84'" && purpose != '84h') {
      throw FormatException("purpose $purpose is not supported");
    }
  }

  static bool hasDescriptorChecksum(String descriptor) {
    final checksumPattern = RegExp(r'#([a-z0-9]{8})$');
    return checksumPattern.hasMatch(descriptor.trim());
  }

  static void validateDescriptorFunction(String descriptorFunction) {
    if (descriptorFunction != allowedDescriptorFunction) {
      throw FormatException('Invalid descriptor function: $descriptorFunction');
    }
  }

  static void validateChecksum(String descriptor) {
    // 체크섬 있는 경우 검증
    if (descriptor.contains("#") && !hasDescriptorChecksum(descriptor)) {
      Logger.log("Invalid descriptor checksum: $descriptor");
      throw FormatException("Invalid descriptor checksum: $descriptor");
    }
  }

  static void validateNativeSegwitDescriptor(String descriptor) {
    final regexWpkhFormatWithoutChecksum = RegExp(
      r"^wpkh\(\[" + _basePath + r"\]" + _xpubPrefix + _base58 + r"\)$",
    );

    final regexWpkhFormatWithChecksumPath = RegExp(
      r"^wpkh\(\[" + _basePath + r"\]" + _xpubPrefix + _base58 + r"/<\d+;\d+>/\*\)$",
    );

    final regexWpkhFormatWithChecksum = RegExp(
      r"^wpkh\(\[" +
          _basePath +
          r"\]" +
          _xpubPrefix +
          _base58 +
          r"/<\d+;\d+>/\*\)#([A-Za-z0-9]{8})$",
    );

    if (!(regexWpkhFormatWithoutChecksum.hasMatch(descriptor) ||
        regexWpkhFormatWithChecksumPath.hasMatch(descriptor) ||
        regexWpkhFormatWithChecksum.hasMatch(descriptor))) {
      Logger.log("Invalid format error: $descriptor");
      throw Exception("Invalid format error");
    }
  }

  static String normalizeDescriptor(String descriptor) {
    validatePurpose(extractPurpose(descriptor));
    final descriptorFunction = getDescriptorFunction(descriptor);
    if (descriptorFunction != null) {
      validateDescriptorFunction(descriptorFunction);
    }

    final finalDescriptor =
        descriptorFunction == null ? wrapWithDescriptorFunction(descriptor) : descriptor;

    validateNativeSegwitDescriptor(finalDescriptor);
    SingleSignatureWallet.fromDescriptor(finalDescriptor,
        ignoreChecksum: !finalDescriptor.contains("#"));
    return finalDescriptor;
  }
}
