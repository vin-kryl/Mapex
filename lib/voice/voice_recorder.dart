import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

/// Records from the microphone into a file. Behind an interface so tests
/// and platforms without a microphone can swap it out.
abstract class VoiceRecorder {
  /// Asks for microphone access if needed. False when it is refused.
  Future<bool> requestPermission();

  /// The file extension recordings get on this platform, without the dot.
  Future<String> extension();

  Future<void> start(String path);

  /// Stops and keeps the file.
  Future<void> stop();

  /// Stops and throws the recording away.
  Future<void> cancel();

  Future<void> dispose();
}

/// The real microphone, through the `record` package.
class MicRecorder implements VoiceRecorder {
  final _rec = AudioRecorder();
  AudioEncoder? _encoder;

  Future<AudioEncoder> _pick() async {
    if (_encoder != null) return _encoder!;
    // AAC in .m4a is small and plays everywhere; WAV is the fallback.
    final aac = await _rec.isEncoderSupported(AudioEncoder.aacLc);
    return _encoder = aac ? AudioEncoder.aacLc : AudioEncoder.wav;
  }

  @override
  Future<bool> requestPermission() => _rec.hasPermission();

  @override
  Future<String> extension() async =>
      await _pick() == AudioEncoder.aacLc ? 'm4a' : 'wav';

  @override
  Future<void> start(String path) async =>
      _rec.start(RecordConfig(encoder: await _pick()), path: path);

  @override
  Future<void> stop() async {
    await _rec.stop();
  }

  @override
  Future<void> cancel() => _rec.cancel();

  @override
  Future<void> dispose() => _rec.dispose();
}

/// A fresh recorder each time one is needed; the caller disposes it.
final voiceRecorderProvider = Provider<VoiceRecorder Function()>(
  (ref) => MicRecorder.new,
);
