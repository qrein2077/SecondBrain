import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

/// Local Whisper (whisper.cpp via whisper_ggml) for Windows desktop.
/// Android is intentionally unsupported in MVP (UI hides the mic).
class WhisperSttService {
  WhisperSttService({
    AudioRecorder? recorder,
    WhisperController? whisper,
    this.model = WhisperModel.base,
  })  : _recorder = recorder ?? AudioRecorder(),
        _whisper = whisper ?? WhisperController();

  /// Prefer `base` — small enough for light PC load, usable for Russian.
  final WhisperModel model;

  final AudioRecorder _recorder;
  final WhisperController _whisper;

  bool _recording = false;
  String? _recordPath;
  bool _modelReady = false;

  bool get isRecording => _recording;

  /// Windows (and Linux for local dev). Android/iOS/web: hide mic for now.
  static bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows || Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasMicPermission() => _recorder.hasPermission();

  Future<void> ensureModel() async {
    if (_modelReady) return;
    await _whisper.downloadModel(model);
    _modelReady = true;
  }

  Future<void> startRecording() async {
    if (!isSupported) {
      throw StateError('Голосовой ввод доступен на Windows (локальный Whisper).');
    }
    if (_recording) return;
    final ok = await _recorder.hasPermission();
    if (!ok) {
      throw StateError('Нет доступа к микрофону. Разрешите запись в Windows.');
    }
    final dir = await getTemporaryDirectory();
    _recordPath =
        '${dir.path}${Platform.pathSeparator}sb_whisper_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordPath!,
    );
    _recording = true;
  }

  /// Stops recording and runs local Whisper. Returns trimmed transcript.
  Future<String> stopAndTranscribe({String lang = 'ru'}) async {
    if (!_recording) return '';
    String? path;
    try {
      path = await _recorder.stop();
    } finally {
      _recording = false;
    }
    final audioPath = (path != null && path.isNotEmpty) ? path : _recordPath;
    if (audioPath == null || audioPath.isEmpty) {
      throw StateError('Запись не сохранена.');
    }
    await ensureModel();
    final result = await _whisper.transcribe(
      model: model,
      audioPath: audioPath,
      lang: lang,
    );
    final text = result?.transcription.text.trim() ?? '';
    return text;
  }

  Future<void> cancelRecording() async {
    if (!_recording) return;
    try {
      await _recorder.stop();
    } catch (_) {}
    _recording = false;
  }

  Future<void> dispose() async {
    await cancelRecording();
    await _recorder.dispose();
  }
}
