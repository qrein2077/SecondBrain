import 'package:whisper_ggml/whisper_ggml.dart';

/// User-selectable Whisper ggml sizes (multilingual). Default: [small].
enum WhisperSize {
  base,
  small,
  medium,
}

extension WhisperSizeX on WhisperSize {
  String get storageValue => name;

  String get labelRu {
    switch (this) {
      case WhisperSize.base:
        return 'base (~142 МБ) — легче, чуть хуже RU';
      case WhisperSize.small:
        return 'small (~466 МБ) — default, лучше RU';
      case WhisperSize.medium:
        return 'medium (~1.5 ГБ) — точнее, тяжелее CPU/RAM';
    }
  }

  String get shortLabel {
    switch (this) {
      case WhisperSize.base:
        return 'base';
      case WhisperSize.small:
        return 'small';
      case WhisperSize.medium:
        return 'medium';
    }
  }

  /// Rough first-download size for UI warnings.
  String get downloadHint {
    switch (this) {
      case WhisperSize.base:
        return '~142 МБ, меньше нагрузка на CPU';
      case WhisperSize.small:
        return '~466 МБ при первом использовании; разумный баланс для RU';
      case WhisperSize.medium:
        return '~1.5 ГБ и заметно больше CPU/RAM — только если small мало';
    }
  }

  WhisperModel get ggmlModel {
    switch (this) {
      case WhisperSize.base:
        return WhisperModel.base;
      case WhisperSize.small:
        return WhisperModel.small;
      case WhisperSize.medium:
        return WhisperModel.medium;
    }
  }

  static WhisperSize fromStorage(String? raw) {
    switch (raw) {
      case 'base':
        return WhisperSize.base;
      case 'medium':
        return WhisperSize.medium;
      case 'small':
      default:
        return WhisperSize.small;
    }
  }
}
