import 'package:coconut_lib/coconut_lib.dart';

class DescriptorUtil {
  static const String allowedDescriptorFunction = 'wpkh';

  static String? getDescriptorFunction(String descriptor) {
    final match = RegExp(r'^(wpkh|wsh|sh|pkh|multi|sortedmulti|tr)\(').firstMatch(descriptor);
    return match?.group(1);
  }

  static String wrapWithDescriptorFunction(String descriptor) {
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

  static String normalizeDescriptor(String descriptor) {
    validatePurpose(extractPurpose(descriptor));
    final descriptorFunction = getDescriptorFunction(descriptor);
    if (descriptorFunction != null) {
      validateDescriptorFunction(descriptorFunction);
    }

    final finalDescriptor =
        descriptorFunction == null ? wrapWithDescriptorFunction(descriptor) : descriptor;
    Descriptor.parse(finalDescriptor, ignoreChecksum: !finalDescriptor.contains("#"));
    return finalDescriptor;
  }
}
