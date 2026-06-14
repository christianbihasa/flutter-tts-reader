import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_service/audio_service.dart';

// Import your custom features
import 'src/audio/reader_audio_handler.dart';
import 'src/parser/pdf_parser_service.dart';
import 'src/audio/system_tts_service.dart';
import 'src/ui/sentence_highlight_reader.dart';

late ReaderAudioHandler globalAudioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  globalAudioHandler = await AudioService.init<ReaderAudioHandler>(
    builder: () => ReaderAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId:
          'io.github.christianbihasa.flutter_tts_reader.channel.audio',
      androidNotificationChannelName: 'Ebook Reader Audio Pipeline',
      androidNotificationOngoing: true,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF6750A4),
        scaffoldBackgroundColor: const Color(0xFFFDFAFF),
        useMaterial3: true,
      ),
      home: const MainReaderScreen(),
    );
  }
}

class MainReaderScreen extends StatefulWidget {
  const MainReaderScreen({super.key});

  @override
  State<MainReaderScreen> createState() => _MainReaderScreenState();
}

class _MainReaderScreenState extends State<MainReaderScreen> {
  final PdfParserService _parser = PdfParserService();
  final SystemTtsService _tts = SystemTtsService();

  bool _isProcessing = false;
  String? _extractedPageText;
  Duration _pageDuration = Duration.zero;
  String _statusMessage = "";

  Future<void> _handleFileSelection() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = "Opening file picker...";
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final file = File(result.files.single.path!);

      // 1. Initialize the TTS Engine background channel
      setState(() => _statusMessage = "Initializing TTS Engine...");
      await _tts.initialize();

      // 2. Extract the first page chunk from your Sprint 1 parser stream
      setState(() => _statusMessage = "Parsing page contents...");
      final Stream<String> pageStream = _parser.parseFilePageByPage(file);

      // Snag the very first page emitted to break the cold-start delay
      final String firstPageText = await pageStream.first;

      if (firstPageText.trim().isEmpty) {
        throw Exception(
          "The first page of this document contains no extractable text.",
        );
      }

      // 3. Synthesize page 0 directly to your Sprint 2 cache location
      setState(() => _statusMessage = "Generating localized audio asset...");
      final File? audioFile = await _tts.synthesizeTextToFile(
        firstPageText,
        "cache_doc_page_0",
      );

      if (audioFile == null || !await audioFile.exists()) {
        throw Exception("Failed to generate local WAV cache file.");
      }

      // 4. Feed the audio handler and let just_audio resolve the true file duration
      setState(() => _statusMessage = "Mounting hardware audio streams...");
      await globalAudioHandler.loadPageChunk(0);

      // Briefly wait for the file stream to initialize so we can read its length
      // Alternately, we approximate standard speaking speed (e.g., 150 words per minute)
      final int wordCount = firstPageText.split(RegExp(r'\s+')).length;
      final Duration estimatedDuration = Duration(
        seconds: ((wordCount / 150) * 60).round(),
      );

      setState(() {
        _extractedPageText = firstPageText;
        _pageDuration = estimatedDuration > Duration.zero
            ? estimatedDuration
            : const Duration(seconds: 10);
        _isProcessing = false;
      });

      // Start background playback instantly
      globalAudioHandler.play();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = "";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🚨 Pipeline Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // LAYOUT LOOP ALTERNATION: Switch view modes depending on state
    if (_extractedPageText != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Active Document Reader"),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                await globalAudioHandler.stop();
                setState(() => _extractedPageText = null);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // The Sprint 3 Interactive Viewport Slicing Highlighter
            Expanded(
              child: SentenceHighlightReader(
                pageText: _extractedPageText!,
                pageAudioDuration: _pageDuration,
              ),
            ),
            // Persistent Playback Controller Bar
            _buildAudioControlPanel(),
          ],
        ),
      );
    }

    // Default Landing / File Picking State View
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isProcessing
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : ElevatedButton.icon(
                  onPressed: _handleFileSelection,
                  icon: const Icon(Icons.file_open_rounded),
                  label: const Text(
                    "Select Document & Start Reader",
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAudioControlPanel() {
    return StreamBuilder<PlaybackState>(
      stream: globalAudioHandler.playbackState,
      builder: (context, snapshot) {
        final playbackState = snapshot.data;
        final playing = playbackState?.playing ?? false;

        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, size: 36),
                onPressed: () => globalAudioHandler.skipToPrevious(),
              ),
              const SizedBox(width: 24),
              FloatingActionButton(
                onPressed: () => playing
                    ? globalAudioHandler.pause()
                    : globalAudioHandler.play(),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 32,
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 36),
                onPressed: () => globalAudioHandler.skipToNext(),
              ),
            ],
          ),
        );
      },
    );
  }
}
