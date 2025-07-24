abstract class IQrScanDataHandler {
  dynamic get result;

  double get progress;

  bool get isFragmented;

  bool isCompleted();

  bool joinData(String data);

  bool validateFormat(String data);

  void reset();
}
