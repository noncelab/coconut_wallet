abstract class IQrScanDataHandler<T> {
  T? get result;

  double get progress;

  bool isCompleted();

  bool joinData(String data);

  bool validateFormat(String data);

  void reset();
}
