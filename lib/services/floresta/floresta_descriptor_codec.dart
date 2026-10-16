import 'package:coconut_lib/coconut_lib.dart';

/// Floresta `loaddescriptor`용 디스크립터 변환기.
/// SLIP-132 키 → 표준 xpub/tpub, multipath `<a;b>` → 단일 경로 2개.
class FlorestaDescriptorCodec {
  static List<String> encode(String descriptor) {
    final standard = _toStandardKeys(descriptor);
    final match = RegExp(r'<(\d+);(\d+)>').firstMatch(standard);
    if (match == null) return [standard];

    String variant(String index) {
      final v = standard.replaceRange(match.start, match.end, index);
      return v.contains('#') ? v.substring(0, v.indexOf('#')) : v;
    }

    return [variant(match.group(1)!), variant(match.group(2)!)];
  }

  /// SLIP-132 extended key(`vpub/zpub/ypub/upub` 등)를 표준 `tpub/xpub`로 바꾼다.
  ///
  /// Floresta(Rust `bitcoin`/miniscript)는 표준 버전 바이트만 파싱하므로
  /// `loaddescriptor` 전에 호출해야 한다. xkey가 실제로 바뀌면 기존 디스크립터
  /// 체크섬이 무효가 되므로 제거한다(Floresta는 체크섬 없는 디스크립터도 허용).
  static String _toStandardKeys(String descriptor) {
    var converted = false;
    final result = descriptor.replaceAllMapped(RegExp(r'[1-9A-HJ-NP-Za-km-z]{107,112}'), (match) {
      final token = match.group(0)!;
      try {
        final standard = ExtendedPublicKey.parse(token, validateNetwork: false).serialize(toXpub: true);
        if (standard != token) converted = true;
        return standard;
      } catch (_) {
        return token;
      }
    });

    if (!converted) return descriptor;
    return result.contains('#') ? result.substring(0, result.indexOf('#')) : result;
  }
}
