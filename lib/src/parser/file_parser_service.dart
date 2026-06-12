import 'dart:io';

abstract class FileParserService {
  /// Emits pages one by one as they are parsed to prevent memory bloating.
  Stream<String> parseFilePageByPage(File file);
}
