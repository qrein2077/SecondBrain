import 'dart:io';
import 'dart:typed_data';

/// Light leading/trailing silence trim for 16-bit PCM WAV (mono or stereo).
/// No-op if the file is not a simple PCM WAV or trim would leave nothing.
class WavSilenceTrim {
  /// [threshold] absolute sample amplitude (0–32767). [padMs] kept around speech.
  static Future<void> trimFile(
    String path, {
    int threshold = 500,
    int padMs = 120,
  }) async {
    final file = File(path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    final trimmed = trimBytes(bytes, threshold: threshold, padMs: padMs);
    if (trimmed == null || identical(trimmed, bytes)) return;
    await file.writeAsBytes(trimmed, flush: true);
  }

  /// Returns new WAV bytes, or null if unchanged / unsupported.
  static Uint8List? trimBytes(
    Uint8List bytes, {
    int threshold = 500,
    int padMs = 120,
  }) {
    if (bytes.length < 44) return null;
    if (bytes[0] != 0x52 ||
        bytes[1] != 0x49 ||
        bytes[2] != 0x46 ||
        bytes[3] != 0x46) {
      return null;
    }
    if (bytes[8] != 0x57 ||
        bytes[9] != 0x41 ||
        bytes[10] != 0x56 ||
        bytes[11] != 0x45) {
      return null;
    }

    var offset = 12;
    int? sampleRate;
    int? channels;
    int? bitsPerSample;
    int? dataOffset;
    int? dataSize;

    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = ByteData.sublistView(bytes, offset + 4, offset + 8)
          .getUint32(0, Endian.little);
      final payload = offset + 8;
      if (id == 'fmt ' && size >= 16 && payload + 16 <= bytes.length) {
        final bd = ByteData.sublistView(bytes, payload, payload + 16);
        final format = bd.getUint16(0, Endian.little);
        if (format != 1) return null; // PCM only
        channels = bd.getUint16(2, Endian.little);
        sampleRate = bd.getUint32(4, Endian.little);
        bitsPerSample = bd.getUint16(14, Endian.little);
      } else if (id == 'data') {
        dataOffset = payload;
        dataSize = size;
        break;
      }
      offset = payload + size + (size.isOdd ? 1 : 0);
    }

    if (sampleRate == null ||
        channels == null ||
        bitsPerSample == null ||
        dataOffset == null ||
        dataSize == null ||
        bitsPerSample != 16) {
      return null;
    }
    if (dataOffset + dataSize > bytes.length) {
      dataSize = bytes.length - dataOffset;
    }

    final frameBytes = channels * (bitsPerSample ~/ 8);
    if (frameBytes <= 0) return null;
    final frameCount = dataSize ~/ frameBytes;
    if (frameCount < 8) return null;

    final pcm = ByteData.sublistView(bytes, dataOffset, dataOffset + dataSize);
    bool loud(int frame) {
      for (var c = 0; c < channels!; c++) {
        final s = pcm.getInt16(frame * frameBytes + c * 2, Endian.little).abs();
        if (s >= threshold) return true;
      }
      return false;
    }

    var start = 0;
    while (start < frameCount && !loud(start)) {
      start++;
    }
    var end = frameCount - 1;
    while (end > start && !loud(end)) {
      end--;
    }
    if (start >= end) return null;

    final padFrames = ((padMs * sampleRate) / 1000).round();
    start = (start - padFrames).clamp(0, frameCount - 1);
    end = (end + padFrames).clamp(0, frameCount - 1);
    final newFrames = end - start + 1;
    if (newFrames >= frameCount) return null; // nothing trimmed

    final newDataSize = newFrames * frameBytes;
    final out = Uint8List(dataOffset + newDataSize);
    out.setRange(0, dataOffset, bytes);
    out.setRange(
      dataOffset,
      dataOffset + newDataSize,
      bytes,
      dataOffset + start * frameBytes,
    );

    // RIFF chunk size = file size - 8
    final riffSize = out.length - 8;
    final bd = ByteData.sublistView(out);
    bd.setUint32(4, riffSize, Endian.little);

    // Patch data chunk size (at dataOffset - 4)
    bd.setUint32(dataOffset - 4, newDataSize, Endian.little);
    return out;
  }
}
