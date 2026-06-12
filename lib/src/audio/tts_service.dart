import 'dart:io';

abstract class TtsService {
  Future<void> initialize();

  /// Synthesizes a chunk of text into a local file instead of live-streaming it.
  Future<File?> synthesizeTextToFile(String text, String filename);

  Future<void> setSpeechRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> stop();
}
