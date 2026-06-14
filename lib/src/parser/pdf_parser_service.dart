import 'dart:io';
import 'package:flutter/services.dart';
import 'file_parser_service.dart';

class PdfParserService implements FileParserService {
  static const MethodChannel _channel = MethodChannel(
    'io.github.christianbihasa/pdf_parser',
  );

  @override
  Stream<String> parseFilePageByPage(File file) async* {
    try {
      // 1. Get the total page count from the native platform
      final int? pageCount = await _channel.invokeMethod<int>(
        'getPageCount',
        {'path': file.path},
      );
      if (pageCount == null || pageCount <= 0) return;

      // 2. Pull text sequentially, keeping the memory baseline completely flat
      for (int i = 0; i < pageCount; i++) {
        final String? pageText = await _channel.invokeMethod<String>(
          'extractPageText',
          {'path': file.path, 'pageNumber': i},
        );

        if (pageText != null && pageText.trim().isNotEmpty) {
          yield pageText;
        }
      }
    } on PlatformException catch (_) {
      // Handle or log platform-specific parsing errors gracefully
      rethrow;
    }
  }
}
