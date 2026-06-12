import 'dart:io';
import 'package:flutter/foundation.dart';
import 'file_parser_service.dart';

class TxtParserService implements FileParserService {
  @override
  Stream<String> parseFilePageByPage(File file) async* {
    // Read and isolate the data loading sequences from the main thread
    final String fullText = await compute(_readTextFileIsolated, file.path);

    // For TXT files, chunk data roughly by line clusters or standard paragraph segments
    final List<String> lines = fullText.split('\n\n');
    for (final chunk in lines) {
      if (chunk.trim().isNotEmpty) {
        yield chunk.trim();
      }
    }
  }

  static Future<String> _readTextFileIsolated(String path) async {
    final file = File(path);
    return await file.readAsString();
  }
}
