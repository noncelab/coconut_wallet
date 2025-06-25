abstract class IQrScanDataHandler {
  dynamic get result;

  double get progress;

  bool isCompleted();

  bool joinData(String data);

  bool validateUrFormat(String data);

  void reset();
}
