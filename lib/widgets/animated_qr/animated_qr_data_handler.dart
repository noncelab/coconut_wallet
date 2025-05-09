import 'package:coconut_wallet/utils/logger.dart';

// TODO: unsigned_transaction_qr_screen.dart에서만 사용되고 있음
// TODO: 코코넛 볼트와 에어갭 통신할 때 사용되어야함..!
// TODO: 코코넛 볼트도 bc_ur 방식으로 통일하면 삭제해도 됨~!
class AnimatedQrDataHandler {
  static const psbtUrType = 'ur:crypto-psbt'; // 14자

  static List<String> splitData(String data) {
    List<String> result = [];
    int length = data.length;
    int start = 0;
    int end = 200; // 232 - 17(헤더 필수문자열들) - 6(N-M 3자리로 가정) = 209
    int splitCount = (length / 200).ceil();
    int index = 1;
    while (start < length) {
      if (end > length) {
        end = length;
      }
      result.add('$psbtUrType/$index-$splitCount/${data.substring(start, end)}');
      start = end;
      end += 200;
      index += 1;
    }
    return result;
  }

  /// splitData로 나눈 데이터의 index를 파싱합니다.
  static int parseIndex(String data) {
    String replaced = data.replaceFirst('$psbtUrType/', '');
    return int.parse(replaced.split('-').first);
  }

  /// ur:crypto-psbt/1-3/... 형태의 데이터에서 3을 파싱해냅니다.
  static int parseTotalCount(String data) {
    String replaced = data.replaceFirst('$psbtUrType/', '');
    return int.parse(replaced.split('-').last.split('/').first);
  }

  /// 데이터를 다시 합칠 수 있는지 검증합니다.
  static bool validateData(List<String> data) {
    try {
      int length = data.length;
      int dataLength = parseTotalCount(data[0]);

      for (int i = 0; i < length; i++) {
        final splited = data[i].split('/');
        if (splited[0] != psbtUrType) {
          return false;
        }

        final sequenceData = splited[1].split('-');
        if (int.parse(sequenceData[0]) != i + 1) {
          return false;
        }

        if (i > 0) {
          if (int.parse(sequenceData[1]) != dataLength) {
            return false;
          }
        }

        final String pureData = parseData(data[i]);
        if (pureData.length > 300 || pureData.isEmpty) {
          return false;
        }
      }
      return true;
    } catch (e) {
      Logger.log('[AnimatedQrDataHandler] validateData error : $e');
      return false;
    }
  }

  static String parseData(String data) {
    String replaced = data.replaceFirst("$psbtUrType/", '');
    String sequenceData = replaced.split('/')[0];

    return replaced.replaceFirst("$sequenceData/", '');
  }

  /// splitData로 나눈 데이터를 합쳐줍니다.
  static String joinData(List<String> data) {
    if (!validateData(data)) {
      throw '[AnimatedQrDataHandler] Invalid data';
    }

    String result = '';
    for (String item in data) {
      result += parseData(item);
    }
    return result;
  }
}
