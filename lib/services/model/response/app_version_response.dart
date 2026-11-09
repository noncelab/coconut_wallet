class AppVersionResponse {
  final String latestVersion;

  /// Play reports availability and a version code rather than a version name.
  final bool? updateAvailable;
  final int? availableVersionCode;
  final String? storeUrl;

  AppVersionResponse({required this.latestVersion, this.updateAvailable, this.availableVersionCode, this.storeUrl});

  // 문자열을 직접 받아와서 객체를 생성하는 팩토리 메서드
  factory AppVersionResponse.fromString(String version) {
    return AppVersionResponse(latestVersion: version);
  }

  @override
  String toString() => 'latestVersion($latestVersion)';
}
