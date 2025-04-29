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

  static void validateBracelets(String descriptor) {
    // 중괄호의 수가 각각 1개씩 있어야 한다.
    if ('('.allMatches(descriptor).length != 1 || ')'.allMatches(descriptor).length != 1) {
      Logger.log("Invalid length of () bracelets: $descriptor");
      throw FormatException("Invalid length of () bracelets: $descriptor");
    }

    // 마지막 중괄호 이후 문자 있는지 확인(체크섬이 있는 경우 제외)
    if (!descriptor.contains("#") && descriptor.substring(descriptor.lastIndexOf(')')).length > 1) {
      Logger.log("Invalid letters after ) bracelet: $descriptor");
      throw FormatException("Invalid letters after ) bracelet: $descriptor");
    }

    // MFP를 사용하는 경우 wpkh( [ 사이에 문자가 있는지 확인한다.
    if (descriptor.contains('[') &&
        descriptor.substring(descriptor.indexOf('('), descriptor.indexOf('[')).length > 1) {
      Logger.log("Invalid letters after ( bracelet: $descriptor");
      throw FormatException("Invalid letters after ( bracelet: $descriptor");
    }

    // 대괄호의 개수가 같아야 하며 각각 2개 이상 존재할 수 없다.
    int squareBracketStartLength = '['.allMatches(descriptor).length;
    int squareBracketEndLength = ']'.allMatches(descriptor).length;
    if (squareBracketStartLength != squareBracketEndLength ||
        squareBracketStartLength > 1 ||
        squareBracketEndLength > 1) {
      Logger.log("Invalid length of [] bracelets: $descriptor");
      throw FormatException("Invalid length of [] bracelets: $descriptor");
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

    validateBracelets(finalDescriptor);
    validateChecksum(finalDescriptor);
    Descriptor.parse(finalDescriptor, ignoreChecksum: !finalDescriptor.contains("#"));
    return finalDescriptor;
  }
}
