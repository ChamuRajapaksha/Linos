import 'dart:typed_data';

/// Reads a PCM16 WAV file (mono or stereo) into normalized [-1, 1] samples.
/// Stereo tracks are averaged to mono. Returns null on malformed headers.
List<double>? readPcm16Wav(List<int> bytes) {
  if (bytes.length < 44) {
    return null;
  }
  final data = Uint8List.fromList(bytes);
  final view = ByteData.sublistView(data);

  if (view.getUint32(0, Endian.little) != 0x46464952) {
    return null;
  }
  if (view.getUint32(8, Endian.little) != 0x45564157) {
    return null;
  }

  int? fmtStart;
  int? dataStart;
  var offset = 12;
  while (offset + 8 <= data.length) {
    final id = view.getUint32(offset, Endian.little);
    final size = view.getUint32(offset + 4, Endian.little);
    if (id == 0x20746D66) {
      fmtStart = offset;
    } else if (id == 0x61746164) {
      dataStart = offset;
    }
    offset += 8 + size;
    if (offset % 2 != 0) {
      offset += 1;
    }
  }

  if (fmtStart == null || dataStart == null) {
    return null;
  }

  final fmt = fmtStart + 8;
  if (view.getUint16(fmt, Endian.little) != 1) {
    return null;
  }
  final numChannels = view.getUint16(fmt + 2, Endian.little);
  if (numChannels < 1) {
    return null;
  }
  if (view.getUint16(fmt + 14, Endian.little) != 16) {
    return null;
  }

  final dataSize = view.getUint32(dataStart + 4, Endian.little);
  final frameCount = dataSize ~/ (2 * numChannels);
  final availableFrames = (data.length - (dataStart + 8)) ~/ (2 * numChannels);
  final count = frameCount < availableFrames ? frameCount : availableFrames;

  final samples = List<double>.filled(count, 0);
  var p = dataStart + 8;
  for (var i = 0; i < count; i++) {
    var acc = 0;
    for (var c = 0; c < numChannels; c++) {
      acc += view.getInt16(p, Endian.little);
      p += 2;
    }
    samples[i] = (acc / numChannels) / 32768.0;
  }
  return samples;
}

/// Builds a minimal PCM16 mono WAV in memory for tests.
Uint8List buildPcm16Wav({
  required List<double> samples,
  required int sampleRate,
  int numChannels = 1,
}) {
  final dataSize = samples.length * 2 * numChannels;
  final buffer = ByteData(44 + dataSize);
  buffer.setUint32(0, 0x46464952, Endian.little);
  buffer.setUint32(4, 36 + dataSize, Endian.little);
  buffer.setUint32(8, 0x45564157, Endian.little);
  buffer.setUint32(12, 0x20746D66, Endian.little);
  buffer.setUint32(16, 16, Endian.little);
  buffer.setUint16(20, 1, Endian.little);
  buffer.setUint16(22, numChannels, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, sampleRate * numChannels * 2, Endian.little);
  buffer.setUint16(32, numChannels * 2, Endian.little);
  buffer.setUint16(34, 16, Endian.little);
  buffer.setUint32(36, 0x61746164, Endian.little);
  buffer.setUint32(40, dataSize, Endian.little);

  var p = 44;
  for (var i = 0; i < samples.length; i++) {
    var value = (samples[i] * 32767).round().clamp(-32768, 32767);
    for (var c = 0; c < numChannels; c++) {
      buffer.setInt16(p, value, Endian.little);
      p += 2;
    }
  }
  return buffer.buffer.asUint8List();
}