String filterNumericInput(String input, {required int decimalPlaces, int integerPlaces = -1}) {
  String allowedCharsInput = input.replaceAll(RegExp(r'[^0-9.]'), '');
  if (input == '00') return '0';
  if (input == '.') return '0.';
  if (RegExp(r'^0[1-9]$').hasMatch(input)) return input.substring(1);

  var splitedInput = allowedCharsInput.split('.');
  if (splitedInput.length == 1 && integerPlaces != -1 && splitedInput[0].length > integerPlaces) {
    /// 정수만 있는 경우 자리수 처리
    return splitedInput[0].substring(0, integerPlaces);
  }

  if (splitedInput.length > 2) {
    return '${splitedInput[0]}.${splitedInput[1]}';
  }

  if (splitedInput.length == 2) {
    /// 소수점까지 있는 경우 자리수 처리
    String integerPart = splitedInput[0];
    String decimalPart = splitedInput[1];

    if (integerPlaces != -1 && splitedInput[0].length > integerPlaces) {
      integerPart = integerPart.substring(0, integerPlaces);
    }
    if (splitedInput[1].length > decimalPlaces) {
      decimalPart = decimalPart.substring(0, decimalPlaces);
    }

    return '$integerPart.$decimalPart';
  }

  return allowedCharsInput;
}
