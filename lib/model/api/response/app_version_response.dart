class AppVersionResponse {
  final String latestVersion;

  AppVersionResponse({
    required this.latestVersion,
  });

  // 문자열을 직접 받아와서 객체를 생성하는 팩토리 메서드
  factory AppVersionResponse.fromString(String version) {
    return AppVersionResponse(latestVersion: version);
  }

  @override
  String toString() => 'latestVersion($latestVersion)';
}
