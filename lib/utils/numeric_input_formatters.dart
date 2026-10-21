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

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (oldValue.text == newValue.text) return newValue;
    final decimalSep = NumberFormatConfig.instance.decimalSeparator;
    final groupingSep = NumberFormatConfig.instance.groupingSeparator;
    final normalized = _normalizeNumericEdit(oldValue, newValue);
    if (normalized == null) return oldValue;
    final text = normalized.text;
    if (text.isEmpty) return normalized;

    final parts = text.split('.');
    if (parts.length > 2) return oldValue;

    final decimalPart = parts.length > 1 ? parts[1] : '';
    if (decimalPart.length > decimalPlaces) return oldValue;

    final integer = int.tryParse(parts[0].isEmpty ? '0' : parts[0]);
    if (integer == null || integer > maxBtc || (integer == maxBtc && decimalPart.contains(RegExp(r'[1-9]')))) {
      return oldValue;
    }

    final formattedText = _formatGroupedDecimalText(text, decimalSeparator: decimalSep, groupingSeparator: groupingSep);
    return _formattedEditingValue(normalized, formattedText, groupingSep);
  }
}

/// 법정화폐(fiat) 금액 입력용. 통화별 소수 자리수(decimalPlaces)만큼만 소수점 입력을 허용한다.
/// decimalPlaces가 0이면 소수점 입력 자체를 거부한다. (예: KRW, JPY)
class FiatAmountInputFormatter extends TextInputFormatter {
  final int decimalPlaces;

  const FiatAmountInputFormatter({required this.decimalPlaces});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (oldValue.text == newValue.text) return newValue;
    final decimalSep = NumberFormatConfig.instance.decimalSeparator;
    final groupingSep = NumberFormatConfig.instance.groupingSeparator;
    final normalized = _normalizeNumericEdit(oldValue, newValue);
    if (normalized == null) return oldValue;
    final text = normalized.text;
    if (text.isEmpty) return normalized;

    final parts = text.split('.');
    if (parts.length > 2) return oldValue;
    if (decimalPlaces == 0 && parts.length > 1) return oldValue;

    final decimalPart = parts.length > 1 ? parts[1] : '';
    if (decimalPart.length > decimalPlaces) return oldValue;

    final formattedText = _formatGroupedDecimalText(text, decimalSeparator: decimalSep, groupingSeparator: groupingSep);
    return _formattedEditingValue(normalized, formattedText, groupingSep);
  }
}

class RateInputFormatter extends TextInputFormatter {
  final int integerPlaces; // 정수부 자리수
  final int decimalPlaces; // 소수부 자리수

  const RateInputFormatter({this.integerPlaces = 8, this.decimalPlaces = 2});

  String get _decimalSep => NumberFormatConfig.instance.decimalSeparator;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (oldValue.text == newValue.text) return newValue;
    final normalizedValue = _normalizeNumericEdit(oldValue, newValue, grouping: false);
    if (normalizedValue == null) return oldValue;
    var normalized = normalizedValue.text;
    if (normalized.isEmpty) return normalizedValue;
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
    return _formattedEditingValue(normalizedValue, formatted, '');
  }
}

class SatoshiAmountInputFormatter extends TextInputFormatter {
  static const int maxSats = 2_100_000_000_000_000;

  const SatoshiAmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (oldValue.text == newValue.text) return newValue;
    final normalized = _normalizeNumericEdit(oldValue, newValue);
    if (normalized == null || normalized.text.contains('.')) return oldValue;
    final text = normalized.text;
    if (text.isEmpty) return normalized;

    final sats = int.tryParse(text);
    if (sats == null || sats > maxSats) return oldValue;

    final groupingSep = NumberFormatConfig.instance.groupingSeparator;
    final formattedText = formatIntWithGroupingSeparator(text.replaceFirst(RegExp(r'^0+(?=\d)'), ''), groupingSep);
    return _formattedEditingValue(normalized, formattedText, groupingSep);
  }
}

/// display 포맷의 금액 텍스트(previous → current)를 비교해 사용자의 키 입력을 추론한다.
///
/// grouping separator는 표시용으로 자동 삽입되는 문자이므로 비교 전에 제거한다.
/// 문자열 중간 삽입/삭제는 없다고 가정하고 꼬리 기준으로 diff한다.
/// - 문자가 삽입된 경우: 삽입된 문자(열) 반환 (로케일 소수점 구분자 포함 가능, 예: ',')
/// - 문자가 삭제된 경우: '<' 반환
/// - 변화가 없는 경우: null 반환
String? resolveAmountKeyInput(String previous, String current) {
  final groupingSep = NumberFormatConfig.instance.groupingSeparator;
  final currentStripped = current.replaceAll(groupingSep, '');
  final previousStripped = previous.replaceAll(groupingSep, '');
  if (currentStripped.length > previousStripped.length) {
    return currentStripped.substring(previousStripped.length);
  } else if (currentStripped.length < previousStripped.length) {
    return '<';
  }
  return null;
}

TextEditingValue? _normalizeNumericEdit(TextEditingValue oldValue, TextEditingValue newValue, {bool grouping = true}) {
  final decimalSep = NumberFormatConfig.instance.decimalSeparator;
  final groupingSep = grouping ? NumberFormatConfig.instance.groupingSeparator : '';
  var start = oldValue.selection.start.clamp(0, oldValue.text.length);
  var oldEnd = oldValue.selection.end.clamp(start, oldValue.text.length);
  var end = newValue.text.length - (oldValue.text.length - oldEnd);
  if (end < start ||
      !newValue.text.startsWith(oldValue.text.substring(0, start)) ||
      !newValue.text.endsWith(oldValue.text.substring(oldEnd))) {
    start = 0;
    while (start < oldValue.text.length &&
        start < newValue.text.length &&
        oldValue.text[start] == newValue.text[start]) {
      start++;
    }
    oldEnd = oldValue.text.length;
    end = newValue.text.length;
    while (oldEnd > start && end > start && oldValue.text[oldEnd - 1] == newValue.text[end - 1]) {
      oldEnd--;
      end--;
    }
  }

  final inserted = newValue.text.substring(start, end);
  var inputDecimal = decimalSep;
  var inputGrouping = '';
  if (inserted.isNotEmpty) {
    final groupedAmount =
        grouping &&
        RegExp(
          '^[1-9][0-9]{0,2}(?:${RegExp.escape(groupingSep)}[0-9]{3})+(?:${RegExp.escape(decimalSep)}[0-9]*)?\$',
        ).hasMatch(inserted);
    if (groupedAmount) {
      inputGrouping = groupingSep;
    } else if (!inserted.contains(decimalSep)) {
      inputDecimal = decimalSep == '.' ? ',' : '.';
    }
    final canonical = inserted.replaceAll(inputGrouping, '').replaceAll(inputDecimal, '.');
    if (!RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(canonical)) return null;
  }

  String normalizePart(String text, String group, String decimal) =>
      text.replaceAll(group, '').replaceAll(decimal, '.');
  String normalizePrefix(int offset) {
    offset = offset.clamp(0, newValue.text.length);
    return normalizePart(newValue.text.substring(0, offset.clamp(0, start)), groupingSep, decimalSep) +
        normalizePart(newValue.text.substring(start, offset.clamp(start, end)), inputGrouping, inputDecimal) +
        normalizePart(newValue.text.substring(end, offset.clamp(end, newValue.text.length)), groupingSep, decimalSep);
  }

  final text = normalizePrefix(newValue.text.length);
  if (!RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(text)) return null;
  return TextEditingValue(
    text: text,
    selection: newValue.selection.copyWith(
      baseOffset: normalizePrefix(newValue.selection.baseOffset).length,
      extentOffset: normalizePrefix(newValue.selection.extentOffset).length,
    ),
    composing:
        newValue.composing.isValid
            ? TextRange(
              start: normalizePrefix(newValue.composing.start).length,
              end: normalizePrefix(newValue.composing.end).length,
            )
            : TextRange.empty,
  );
}

String _formatGroupedDecimalText(String text, {required String decimalSeparator, required String groupingSeparator}) {
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

TextEditingValue _formattedEditingValue(TextEditingValue normalized, String formatted, String groupingSeparator) {
  final integer = normalized.text.split('.').first;
  final removedZeros = integer.length - integer.replaceFirst(RegExp(r'^0+(?=\d)'), '').length;
  int offset(int position) {
    var remaining = (position - removedZeros).clamp(0, normalized.text.length);
    if (normalized.text.startsWith('.') && position > 0) remaining++;
    if (remaining == 0) return 0;
    for (var i = 0; i < formatted.length; i++) {
      if (formatted[i] != groupingSeparator) remaining--;
      if (remaining == 0) return i + 1;
    }
    return formatted.length;
  }

  return TextEditingValue(
    text: formatted,
    selection: normalized.selection.copyWith(
      baseOffset: offset(normalized.selection.baseOffset),
      extentOffset: offset(normalized.selection.extentOffset),
    ),
    composing:
        normalized.composing.isValid
            ? TextRange(start: offset(normalized.composing.start), end: offset(normalized.composing.end))
            : TextRange.empty,
  );
}
