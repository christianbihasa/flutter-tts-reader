import 'dart:io';
import '../parser/pdf_parser_service.dart';
import '../audio/system_tts_service.dart';

class Sprint1TestHarness {
  final PdfParserService _parser = PdfParserService();
  final SystemTtsService _tts = SystemTtsService();

  Future<void> runLocalExecutionLoop(String testFilePath) async {
    final file = File(testFilePath);
    if (!await file.exists()) {
      print(
        "❌ [Harness Error]: Test file does not exist at path: $testFilePath",
      );
      return;
    }

    print("🚀 [Harness]: Initializing System TTS Service...");
    await _tts.initialize();

    print("📦 [Harness]: Starting sequential streaming for: ${file.path}");
    int pageIndex = 0;
    final stopwatch = Stopwatch()..start();

    try {
      // The 'await for' loop natively respects the stream's pacing.
      // It won't request page 2 until page 1 finishes synthesis.
      await for (final pageText in _parser.parseFilePageByPage(file)) {
        pageIndex++;
        print(
          "\n📄 [Page $pageIndex Emitted] Length: ${pageText.length} characters",
        );

        // Prevent empty or whitespace-only chunks from choking the engine
        if (pageText.trim().isEmpty) {
          print("⚠️ [Page $pageIndex]: Skipping empty block.");
          continue;
        }

        // Create a predictable, non-colliding filename for the cache chunk
        final String audioFilename = "cache_doc_page_$pageIndex";
        print(
          "🎙️ [Page $pageIndex]: Synthesizing text to local audio file...",
        );

        final File? audioOutputFile = await _tts.synthesizeTextToFile(
          pageText,
          audioFilename,
        );

        if (audioOutputFile != null && await audioOutputFile.exists()) {
          final int byteSize = await audioOutputFile.length();
          print(
            "✅ [Page $pageIndex Success]: File created at: ${audioOutputFile.path} (${(byteSize / 1024).toStringAsFixed(2)} KB)",
          );
        } else {
          print(
            "❌ [Page $pageIndex Failure]: Native TTS engine failed to output a file.",
          );
        }
      }

      stopwatch.stop();
      print(
        "\n🏁 [Harness Complete]: Handled $pageIndex pages in ${stopwatch.elapsed.inSeconds} seconds.",
      );
    } catch (e) {
      print("💥 [Harness Crash]: An error occurred during loop execution: $e");
    } finally {
      await _tts.stop();
    }
  }
}
