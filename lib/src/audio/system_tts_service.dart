import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'tts_service.dart';

class SystemTtsService implements TtsService {
  late FlutterTts _flutterTts;
  late String _cacheDirectoryPath;

  @override
  Future<void> initialize() async {
    _flutterTts = FlutterTts();

    // Direct audio synthesis payloads to the app's secure transient document directory
    final Directory tempDir = await getTemporaryDirectory();
    _cacheDirectoryPath = tempDir.path;

    // Configure fallback properties for standard systems
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
  }

  @override
  Future<File?> synthesizeTextToFile(String text, String filename) async {
    if (text.trim().isEmpty) return null;

    final String targetFilePath = '$_cacheDirectoryPath/$filename.wav';

    // Execute platform specific audio rendering loops straight to physical storage targets
    // Note: flutter_tts returns 1 on Android/iOS platforms for a successful synthesis command pipeline initiation
    final dynamic result = await _flutterTts.synthesizeToFile(
      text,
      targetFilePath,
    );

    if (result == 1 || result == true) {
      final File synthesizedFile = File(targetFilePath);
      // Wait up to a small threshold for completion processing guarantees if needed by platform hooks
      return synthesizedFile;
    }

    return null;
  }

  @override
  Future<void> setSpeechRate(double rate) async =>
      await _flutterTts.setSpeechRate(rate);

  @override
  Future<void> setPitch(double pitch) async =>
      await _flutterTts.setPitch(pitch);

  @override
  Future<void> stop() async => await _flutterTts.stop();
}
