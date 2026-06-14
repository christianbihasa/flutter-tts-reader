import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';

import 'src/audio/reader_audio_handler.dart';
import 'src/services/session_manager.dart';
import 'src/ui/sentence_highlight_reader.dart';

late ReaderAudioHandler globalAudioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  globalAudioHandler = await AudioService.init<ReaderAudioHandler>(
    builder: () => ReaderAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId:
          'io.github.christianbihasa.flutter_tts_reader.channel.audio',
      androidNotificationChannelName: 'Ebook Reader Audio Service',
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
  bool _isProcessing = true;
  String _statusMessage = "Checking for bookmarked sessions...";
  String? _activePageText;

  @override
  void initState() {
    super.initState();
    _tryHydrateExistingSession();
  }

  /// Checks local storage settings to automatically recover active documents
  Future<void> _tryHydrateExistingSession() async {
    try {
      final session = await SessionManager.getActiveSession();
      if (session != null) {
        final String fileName = session['fileName'];
        final int savedPageIndex = session['pageIndex'];

        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final File persistentFile = File('${appDocDir.path}/$fileName');

        if (await persistentFile.exists()) {
          setState(() => _statusMessage = "Resuming your last session...");
          await globalAudioHandler.initializeDocument(
            persistentFile,
            savedPageIndex,
          );
          _mountActivePageDisplay();
          return;
        }
      }
    } catch (_) {}
    setState(() => _isProcessing = false);
  }

  Future<void> _handleFileSelection() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = "Opening File Explorer...";
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );
      if (result == null || result.files.single.path == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final File pickedFile = File(result.files.single.path!);
      final String fileName = result.files.single.name;

      // OPTIMAL DECISION: Copy asset to secure permanent Application Storage Window
      setState(
        () => _statusMessage = "Securing file to application sandbox...",
      );
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final File permanentSavedFile = await pickedFile.copy(
        '${appDocDir.path}/$fileName',
      );

      setState(() => _statusMessage = "Compiling document matrices...");
      await globalAudioHandler.initializeDocument(permanentSavedFile, 0);
      _mountActivePageDisplay();

      globalAudioHandler.play();
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Pipeline Rejection: $e")));
    }
  }

  void _mountActivePageDisplay() {
    final int idx = globalAudioHandler.currentPageIndex;
    if (idx < globalAudioHandler.cachedPageTexts.length) {
      setState(() {
        _activePageText = globalAudioHandler.cachedPageTexts[idx];
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activePageText != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Page ${globalAudioHandler.currentPageIndex + 1}"),
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmark_remove),
              onPressed: () async {
                await globalAudioHandler.stop();
                await SessionManager.clearSession();
                setState(() => _activePageText = null);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SentenceHighlightReader(
                pageText: _activePageText!,
                pageAudioDuration: const Duration(
                  seconds: 15,
                ), // Adjusted internally per map index
              ),
            ),
            _buildControlBar(),
          ],
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage),
                ],
              )
            : ElevatedButton.icon(
                onPressed: _handleFileSelection,
                icon: const Icon(Icons.file_open),
                label: const Text("Import Document"),
              ),
      ),
    );
  }

  Widget _buildControlBar() {
    return StreamBuilder<PlaybackState>(
      stream: globalAudioHandler.playbackState,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 32),
                onPressed: () async {
                  await globalAudioHandler.skipToPrevious();
                  _mountActivePageDisplay();
                },
              ),
              const SizedBox(width: 30),
              FloatingActionButton(
                onPressed: () => playing
                    ? globalAudioHandler.pause()
                    : globalAudioHandler.play(),
                child: Icon(playing ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 30),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 32),
                onPressed: () async {
                  await globalAudioHandler.skipToNext();
                  _mountActivePageDisplay();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
