abstract class ICoconutQrDataHandler {
  dynamic get result;

  Future<void> initialize(Map<String, dynamic> data);

  bool isCompleted();

  bool joinData(String data);

  void reset();
}
