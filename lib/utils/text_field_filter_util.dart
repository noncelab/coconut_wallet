import 'package:flutter/services.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';

String filterNumericInput(
  String input, {
  required int decimalPlaces,
  int integerPlaces = -1,
}) {
  String allowedCharsInput = input.replaceAll(RegExp(r'[^0-9.]'), '');
  if (input == '00') return '0';
  if (input == '.') return '0.';
  if (RegExp(r'^0[1-9]$').hasMatch(input)) return input.substring(1);

  var splitedInput = allowedCharsInput.split('.');
  if (splitedInput.length == 1 &&
      integerPlaces != -1 &&
      splitedInput[0].length > integerPlaces) {
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

class BtcAmountInputFormatter extends TextInputFormatter {
  static const double maxBtc = 21_000_000;

  final int decimalPlaces;

  const BtcAmountInputFormatter({this.decimalPlaces = 8});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (text.isEmpty) return newValue;

    final parts = text.split('.');
    if (parts.length > 2) return oldValue;

    final decimalPart = parts.length > 1 ? parts[1] : '';
    if (decimalPart.length > decimalPlaces) return oldValue;

    final btc = double.tryParse(text);
    if (btc != null && btc > maxBtc) return oldValue;

    final formattedText = _formatBtcText(text);
    final offset = _calculateSelectionOffset(
      originalText: newValue.text,
      formattedText: formattedText,
      baseOffset: newValue.selection.baseOffset,
    );
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class SatoshiAmountInputFormatter extends TextInputFormatter {
  static const int maxSats = 2_100_000_000_000_000;

  const SatoshiAmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.isEmpty) return newValue;

    final sats = int.tryParse(text);
    if (sats != null && sats > maxSats) return oldValue;

    final formattedText = int.parse(text).toThousandsSeparatedString();
    final offset = _calculateSelectionOffset(
      originalText: newValue.text,
      formattedText: formattedText,
      baseOffset: newValue.selection.baseOffset,
    );
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

String _formatBtcText(String text) {
  if (text == '.') return '0.';

  final parts = text.split('.');
  final integerPart = parts[0].isEmpty ? '0' : parts[0];
  final formattedIntegerPart = int.parse(integerPart).toThousandsSeparatedString();

  if (parts.length == 1) {
    return formattedIntegerPart;
  }

  return '$formattedIntegerPart.${parts[1]}';
}

int _calculateSelectionOffset({
  required String originalText,
  required String formattedText,
  required int baseOffset,
}) {
  final clampedOffset = baseOffset.clamp(0, originalText.length);
  final meaningfulCharCount = originalText
      .substring(0, clampedOffset)
      .replaceAll(',', '')
      .length;

  var seenMeaningfulChars = 0;
  for (var i = 0; i < formattedText.length; i++) {
    if (formattedText[i] != ',') {
      seenMeaningfulChars++;
    }
    if (seenMeaningfulChars >= meaningfulCharCount) {
      return i + 1;
    }
  }

  return formattedText.length;
}
