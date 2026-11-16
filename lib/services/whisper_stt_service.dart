import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import '../models/stt_transcript.dart';
import '../models/whisper_size.dart';
import 'stt_confidence.dart';
import 'wav_silence_trim.dart';

/// Local Whisper (whisper.cpp via whisper_ggml) for Windows desktop.
/// Android is intentionally unsupported in MVP (UI hides the mic).
class WhisperSttService {
  WhisperSttService({
    AudioRecorder? recorder,
    WhisperController? whisper,
    this.size = WhisperSize.small,
  })  : _recorder = recorder ?? AudioRecorder(),
        _whisper = whisper ?? WhisperController();

  final AudioRecorder _recorder;
  final WhisperController _whisper;

  WhisperSize size;
  WhisperModel? _readyModel;
  bool _recording = false;
  String? _recordPath;

  bool get isRecording => _recording;

  /// Always force Russian for SecondBrain MVP.
  static const forcedLang = 'ru';

  /// Windows (and Linux for local dev). Android/iOS/web: hide mic for now.
  static bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows || Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  void setSize(WhisperSize next) {
    if (size == next) return;
    size = next;
    if (_readyModel != next.ggmlModel) {
      _readyModel = null;
    }
  }

  Future<bool> hasMicPermission() => _recorder.hasPermission();

  Future<void> ensureModel() async {
    final model = size.ggmlModel;
    if (_readyModel == model) return;
    await _whisper.downloadModel(model);
    _readyModel = model;
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
        bitRate: 256000,
      ),
      path: _recordPath!,
    );
    _recording = true;
  }

  /// Stops recording, lightly trims silence, runs Whisper with [forcedLang].
  ///
  /// Returns [SttTranscript] with heuristic confidence (whisper_ggml has no
  /// token probabilities — we use word timestamps + text heuristics).
  Future<SttTranscript> stopAndTranscribe() async {
    if (!_recording) {
      return const SttTranscript(text: '', words: []);
    }
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

    try {
      await WavSilenceTrim.trimFile(audioPath);
    } catch (_) {}

    await ensureModel();
    final result = await _whisper.transcribe(
      model: size.ggmlModel,
      audioPath: audioPath,
      lang: forcedLang,
      withSegments: true,
      splitOnWord: true,
      suppressNonSpeechTokens: true,
    );

    final full = result?.transcription.text.trim() ?? '';
    final segs = result?.transcription.segments;
    if (segs == null || segs.isEmpty) {
      return SttConfidenceHeuristics.fromPlainText(full);
    }

    final mapped = segs
        .map(
          (s) => (
            text: s.text,
            fromMs: s.fromTs.inMilliseconds,
            toMs: s.toTs.inMilliseconds,
          ),
        )
        .toList();
    return SttConfidenceHeuristics.fromSegments(
      fullText: full,
      segments: mapped,
    );
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
