String filterDecimalInput(String input, int decimalPlaces) {
  String allowedCharsInput = input.replaceAll(RegExp(r'[^0-9.]'), '');
  if (input == '00') return '0';
  if (input == '.') return '0.';

  var splitedInput = allowedCharsInput.split('.');
  if (splitedInput.length > 2) {
    return '${splitedInput[0]}.${splitedInput[1]}';
  }

  if (splitedInput.length == 2 && splitedInput[1].length > decimalPlaces) {
    return '${splitedInput[0]}.${splitedInput[1].substring(0, decimalPlaces)}';
  }

  return allowedCharsInput;
}
