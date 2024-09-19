import 'package:coconut_wallet/utils/logger.dart';

void printLongString(String str) {
  const int chunkSize = 500;
  int length = str.length;
  int start = 0;

  while (start < length) {
    int end = start + chunkSize;
    if (end > length) {
      end = length;
    }
    Logger.log(str.substring(start, end));
    start = end;
  }
}
