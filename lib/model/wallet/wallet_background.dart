import 'dart:ui';

/// 지갑 카드 배경. 값이 없으면(null) 테마 기본 바탕을 쓴다.
sealed class WalletBackground {
  const WalletBackground();

  Map<String, dynamic> toJson();

  static WalletBackground? fromJson(Object? json) {
    if (json is! Map) return null;
    switch (json['type']) {
      case WalletSkinBackground.type:
        final skinId = json['skinId'];
        return skinId is String ? WalletSkinBackground(skinId) : null;
      case WalletColorBackground.type:
        final argb = json['color'];
        return argb is int ? WalletColorBackground(argb) : null;
      case WalletPhotoBackground.type:
        final fileName = json['fileName'];
        final aspectRatio = _toDouble(json['aspectRatio']);
        if (fileName is! String || aspectRatio == null || aspectRatio <= 0) return null;
        return WalletPhotoBackground(
          fileName: fileName,
          aspectRatio: aspectRatio,
          focusX: _toDouble(json['focusX']) ?? 0,
          focusY: _toDouble(json['focusY']) ?? 0,
          scale: _toDouble(json['scale']) ?? 1,
        );
    }
    return null;
  }

  static double? _toDouble(Object? value) => value is num ? value.toDouble() : null;
}

class WalletSkinBackground extends WalletBackground {
  static const type = 'skin';

  final String skinId;

  const WalletSkinBackground(this.skinId);

  @override
  Map<String, dynamic> toJson() => {'type': type, 'skinId': skinId};

  @override
  bool operator ==(Object other) => other is WalletSkinBackground && other.skinId == skinId;

  @override
  int get hashCode => skinId.hashCode;
}

/// 사용자가 고른 단색. [argb]는 불투명 색의 32비트 값이다.
class WalletColorBackground extends WalletBackground {
  static const type = 'color';

  final int argb;

  const WalletColorBackground(this.argb);

  WalletColorBackground.of(Color color) : argb = color.withValues(alpha: 1).toARGB32();

  Color get color => Color(argb);

  @override
  Map<String, dynamic> toJson() => {'type': type, 'color': argb};

  @override
  bool operator ==(Object other) => other is WalletColorBackground && other.argb == argb;

  @override
  int get hashCode => argb.hashCode;
}

/// 사용자가 고른 사진 배경.
///
/// - 잘라낸 사본이 아니라 원본(줄인 사본)을 두고, 카드·상세 배경 등 비율이 다른 곳마다 `cover`로 채운다.
/// - [focusX], [focusY]는 -1~1 범위의 [Alignment] 값이다. 남는 부분 중 어디를 보여 줄지 정한다.
/// - [scale]은 `cover` 크기에 곱하는 확대 배율이다(1 이상).
/// - [fileName]은 앱 문서 폴더 기준 이름이다. iOS는 앱을 업데이트하면 문서 폴더의 절대 경로가 바뀐다.
class WalletPhotoBackground extends WalletBackground {
  static const type = 'photo';
  static const double maxScale = 4;

  final String fileName;
  final double aspectRatio;
  final double focusX;
  final double focusY;
  final double scale;

  const WalletPhotoBackground({
    required this.fileName,
    required this.aspectRatio,
    this.focusX = 0,
    this.focusY = 0,
    this.scale = 1,
  });

  WalletPhotoBackground copyWith({double? focusX, double? focusY, double? scale}) {
    return WalletPhotoBackground(
      fileName: fileName,
      aspectRatio: aspectRatio,
      focusX: (focusX ?? this.focusX).clamp(-1.0, 1.0),
      focusY: (focusY ?? this.focusY).clamp(-1.0, 1.0),
      scale: (scale ?? this.scale).clamp(1.0, maxScale),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'fileName': fileName,
    'aspectRatio': aspectRatio,
    'focusX': focusX,
    'focusY': focusY,
    'scale': scale,
  };

  @override
  bool operator ==(Object other) =>
      other is WalletPhotoBackground &&
      other.fileName == fileName &&
      other.aspectRatio == aspectRatio &&
      other.focusX == focusX &&
      other.focusY == focusY &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(fileName, aspectRatio, focusX, focusY, scale);
}
