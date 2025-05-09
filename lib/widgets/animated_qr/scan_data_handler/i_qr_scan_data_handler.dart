abstract class IQrScanDataHandler {
  dynamic get result;

  bool isCompleted();

  bool joinData(String data);

  void reset();
}
