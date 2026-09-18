abstract class IQrViewDataHandler {
  final String source;

  IQrViewDataHandler(this.source, Map<String, dynamic> data);

  String nextPart();
}
