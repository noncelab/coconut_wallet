import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:flutter/services.dart';

String filterNumericInput(String input, {required int decimalPlaces, int integerPlaces = -1}) {
  String allowedCharsInput = input.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
  if (input == '00') return '0';
  if (input == '.' || input == ',') return '0.';
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

class BtcAmountInputFormatter extends TextInputFormatter {
  static const double maxBtc = 21_000_000;

  final int decimalPlaces;

  const BtcAmountInputFormatter({this.decimalPlaces = 8});

  // decimalSeparator와 반대 구분자
  String get _altSeparator => NumberFormatConfig.instance.decimalSeparator == '.' ? ',' : '.';

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final decimalSep = NumberFormatConfig.instance.decimalSeparator;
    final groupingSep = NumberFormatConfig.instance.groupingSeparator;
    final inserted = _insertedText(oldValue, newValue);
    if (inserted.isNotEmpty) {
      if (!RegExp(r'^[0-9.,]+$').hasMatch(inserted)) return oldValue;

      // 반대 구분자 입력: 소수점이 아직 없는 경우에만 소수점으로 변환, 있으면 거부
      if (inserted == _altSeparator) {
        final alreadyHasDecimal = oldValue.text.contains(decimalSep);
        if (alreadyHasDecimal) return oldValue;
        // 소수점으로 대체
        final newText = newValue.text.substring(0, newValue.text.length - 1) + decimalSep;
        final next = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
        return formatEditUpdate(oldValue, next);
      }

      // groupingSeparator 직접 입력은 거부
      if (inserted == groupingSep) return oldValue;
    }

    // groupingSeparator를 먼저 제거한 뒤 마침표/쉼표를 모두 .으로 통일
    final text = newValue.text.replaceAll(groupingSep, '').replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    if (text.isEmpty) return newValue;

    final parts = text.split('.');
    if (parts.length > 2) return oldValue;

    final decimalPart = parts.length > 1 ? parts[1] : '';
    if (decimalPart.length > decimalPlaces) return oldValue;

    final btc = double.tryParse(text);
    if (btc != null && btc > maxBtc) return oldValue;

    final formattedText = _formatBtcText(text, decimalSeparator: decimalSep, groupingSeparator: groupingSep);
    final offset = _calculateSelectionOffset(
      originalText: newValue.text,
      formattedText: formattedText,
      baseOffset: newValue.selection.baseOffset,
      decimalSeparator: decimalSep,
      groupingSeparator: groupingSep,
    );
    return TextEditingValue(text: formattedText, selection: TextSelection.collapsed(offset: offset));
  }
}

class RateInputFormatter extends TextInputFormatter {
  final int integerPlaces; // 정수부 자리수
  final int decimalPlaces; // 소수부 자리수

  const RateInputFormatter({this.integerPlaces = 8, this.decimalPlaces = 2});

  String get _decimalSep => NumberFormatConfig.instance.decimalSeparator;
  String get _altSep => _decimalSep == '.' ? ',' : '.';

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final inserted = _insertedText(oldValue, newValue);
    if (inserted.isNotEmpty) {
      if (!RegExp(r'^[0-9.,]+$').hasMatch(inserted)) return oldValue;

      if (inserted == _altSep) {
        if (oldValue.text.contains(_decimalSep)) return oldValue;
        final newText = newValue.text.substring(0, newValue.text.length - 1) + _decimalSep;
        final next = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
        return formatEditUpdate(oldValue, next);
      }
    }

    var normalized = newValue.text.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    if (normalized.isEmpty) return newValue;
    // 맨 앞에 소수점이 오면 0.으로 변환
    if (normalized.startsWith('.')) {
      normalized = '0$normalized';
    }
    final parts = normalized.split('.');
    if (parts.length > 2) return oldValue;
    final integerPart = parts[0].replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final decimalPart = parts.length == 2 ? parts[1] : null;
    if (integerPart.length > integerPlaces) return oldValue;
    if (decimalPart != null && decimalPart.length > decimalPlaces) {
      return oldValue;
    }

    final formatted = decimalPart != null ? '$integerPart$_decimalSep$decimalPart' : integerPart;
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

class SatoshiAmountInputFormatter extends TextInputFormatter {
  static const int maxSats = 2_100_000_000_000_000;

  const SatoshiAmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.isEmpty) return newValue;

    final sats = int.tryParse(text);
    if (sats != null && sats > maxSats) return oldValue;

    final formattedText = formatIntWithGroupingSeparator(text, NumberFormatConfig.instance.groupingSeparator);
    final offset = _calculateSelectionOffset(
      originalText: newValue.text,
      formattedText: formattedText,
      baseOffset: newValue.selection.baseOffset,
      groupingSeparator: NumberFormatConfig.instance.groupingSeparator,
    );
    return TextEditingValue(text: formattedText, selection: TextSelection.collapsed(offset: offset));
  }
}

String _insertedText(TextEditingValue oldValue, TextEditingValue newValue) {
  if (newValue.text.length <= oldValue.text.length) return '';

  final start = oldValue.selection.baseOffset.clamp(0, oldValue.text.length);
  final end = (start + (newValue.text.length - oldValue.text.length)).clamp(0, newValue.text.length);
  return newValue.text.substring(start, end);
}

String _formatBtcText(String text, {required String decimalSeparator, required String groupingSeparator}) {
  if (text == '.' || text == ',') return '0$decimalSeparator';

  final parts = text.replaceAll(',', '.').split('.');
  final rawIntegerPart = parts[0].isEmpty ? '0' : parts[0];
  final integerPart = rawIntegerPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final formattedIntegerPart = formatIntWithGroupingSeparator(integerPart, groupingSeparator);

  if (parts.length == 1) {
    return formattedIntegerPart;
  }

  return '$formattedIntegerPart$decimalSeparator${parts[1]}';
}

String formatIntWithGroupingSeparator(String integer, String groupingSeparator) {
  final isNegative = integer.startsWith('-');
  final digits = isNegative ? integer.substring(1) : integer;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(groupingSeparator);
    }
    buffer.write(digits[i]);
  }
  return isNegative ? '-${buffer.toString()}' : buffer.toString();
}

int _calculateSelectionOffset({
  required String originalText,
  required String formattedText,
  required int baseOffset,
  String decimalSeparator = '.',
  String groupingSeparator = ',',
}) {
  final clampedOffset = baseOffset.clamp(0, originalText.length);

  // .을 입력하면 0.으로 바뀌는 경우(BTC 단위 입력 시 해당) .뒤에 커서를 두기 위해 따로 처리
  if ((originalText.startsWith('.') || originalText.startsWith(',')) &&
      formattedText.startsWith('0$decimalSeparator')) {
    return (clampedOffset + 1).clamp(0, formattedText.length);
  }

  final textBeforeCursor = originalText.substring(0, clampedOffset);
  if (textBeforeCursor.endsWith('.') || textBeforeCursor.endsWith(',')) {
    final decimalOffset = formattedText.indexOf(decimalSeparator) + 1;
    if (decimalOffset > 0) return decimalOffset;
  }

  final meaningfulCharCount = textBeforeCursor.replaceAll(groupingSeparator, '').length;

  var seenMeaningfulChars = 0;
  for (var i = 0; i < formattedText.length; i++) {
    if (formattedText[i] != groupingSeparator) {
      seenMeaningfulChars++;
    }
    if (seenMeaningfulChars >= meaningfulCharCount) {
      return i + 1;
    }
  }

  return formattedText.length;
}
