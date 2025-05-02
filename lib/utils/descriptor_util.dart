import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/logger.dart';

class DescriptorUtil {
  static const String allowedDescriptorFunction = 'wpkh';

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
    final regex = RegExp(r'\[([0-9a-fA-F]{8})/([0-9]+' r"')" r'(?:/[0-9]+' r"')*]");

    final match = regex.firstMatch(innerDescriptor);
    if (match == null || match.groupCount < 2) {
      throw const FormatException('Invalid descriptor format');
    }

    //final fingerprint = match.group(1)!;
    final purposeWithHardenedMark = match.group(2)!;
    final purpose = purposeWithHardenedMark.replaceAll("'", ""); // 숫자만 추출

    return purpose;
  }

  static void validatePurpose(String purpose) {
    if (purpose != '84') {
      throw const FormatException('Invalid purpose');
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
      r"^wpkh\(\[[0-9a-fA-F]{8}/84(?:'|h)/(?:1|0)(?:'|h)/0(?:'|h)\](vpub|ypub|zpub|xpub|tpub)[1-9A-HJ-NP-Za-km-z]{107}\)$",
    );
    final regexWpkhFormatWithChecksumPath = RegExp(
      r"^wpkh\(\[[0-9a-fA-F]{8}/84(?:'|h)/(?:1|0)(?:'|h)/0(?:'|h)\](vpub|ypub|zpub|xpub|tpub)[1-9A-HJ-NP-Za-km-z]{107}/<\d+;\d+>\/\*\)$",
    );
    final regexWpkhFormatWithChecksum = RegExp(
      r"^wpkh\(\[[0-9a-fA-F]{8}/84(?:'|h)/(?:1|0)(?:'|h)/0(?:'|h)\](vpub|ypub|zpub|xpub|tpub)[1-9A-HJ-NP-Za-km-z]{107}/<\d+;\d+>\/\*\)#([A-Za-z0-9]{8})$",
    );

    if (!(regexWpkhFormatWithoutChecksum.hasMatch(descriptor) ||
        regexWpkhFormatWithChecksumPath.hasMatch(descriptor) ||
        regexWpkhFormatWithChecksum.hasMatch(descriptor))) {
      throw Exception("Invalid format error");
    }
  }

  static String normalizeDescriptor(String descriptor) {
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
