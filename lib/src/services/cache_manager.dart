import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheManager {
  static const String filePrefix = "cache_doc_page_";

  /// Retains only the current, previous, and next page audio chunks on disk.
  static Future<void> enforceSlidingWindow(int currentPageIndex) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return;

      final int lowerBound = currentPageIndex - 1;
      final int upperBound = currentPageIndex + 1;

      // List all items in transient storage
      final List<FileSystemEntity> entities = tempDir.listSync();

      for (final entity in entities) {
        if (entity is File) {
          final String fileName = entity.path
              .split(Platform.pathSeparator)
              .last;

          // Isolate tracking vectors matching our specialized audio naming standard
          if (fileName.startsWith(filePrefix) && fileName.endsWith('.wav')) {
            // Extract the page index from the filename string (e.g., cache_doc_page_3.wav)
            final String indexPart = fileName
                .replaceAll(filePrefix, '')
                .replaceAll('.wav', '');

            final int? pageIndex = int.tryParse(indexPart);

            if (pageIndex != null) {
              // Delete files outside our strict [Current - 1, Current, Current + 1] window
              if (pageIndex < lowerBound || pageIndex > upperBound) {
                if (await entity.exists()) {
                  await entity.delete();
                }
              }
            }
          }
        }
      }
    } catch (_) {
      // Fail silently to safeguard background playback continuity
    }
  }
}
