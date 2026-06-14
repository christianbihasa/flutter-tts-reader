import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../services/cache_manager.dart';
import '../services/session_manager.dart';
import '../services/telemetry_service.dart';
import '../parser/pdf_parser_service.dart';
import '../parser/txt_parser_service.dart';
import 'system_tts_service.dart';

class ReaderAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  final PdfParserService _pdfParser = PdfParserService();
  final TxtParserService _txtParser = TxtParserService();
  final SystemTtsService _ttsService = SystemTtsService();
  final List<String> _cachedPageTexts = [];
  int _currentPageIndex = 0;
  bool _isTransitioning = false;
  File? _currentDocument;
  StreamSubscription<ProcessingState>? _processingStateSubscription;

  ReaderAudioHandler() {
    _initPlayerStreams();
  }

  int get currentPageIndex => _currentPageIndex;
  List<String> get cachedPageTexts => _cachedPageTexts;
  
  /// Returns the actual duration of the audio for a given page index
  Duration? getPageAudioDuration(int pageIndex) {
    if (_player.duration != null) {
      return _player.duration;
    }
    // Return null if duration is not yet available
    return null;
  }

  void _initPlayerStreams() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _processingStateSubscription = _player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        await _handlePageCompletion();
      }
    });
  }

  Future<void> initializeDocument(File file, int initialPage) async {
    _currentDocument = file;
    _currentPageIndex = initialPage;
    _cachedPageTexts.clear();

    try {
      // Detect file type and use appropriate parser
      final String filePath = file.path.toLowerCase();
      final Stream<String> pageStream;
      
      if (filePath.endsWith('.pdf')) {
        pageStream = _pdfParser.parseFilePageByPage(file);
      } else if (filePath.endsWith('.txt')) {
        pageStream = _txtParser.parseFilePageByPage(file);
      } else {
        throw UnsupportedError('File type not supported');
      }

      // Enforce zero-lag text streams
      await for (final pageText in pageStream) {
        _cachedPageTexts.add(pageText);
      }

      if (_cachedPageTexts.isEmpty) {
        // Handle fully unreadable or completely blank documents gracefully
        _cachedPageTexts.add("Document contains no readable text layers.");
      }

      await _ttsService.initialize();
      await loadPageChunk(_currentPageIndex);
    } catch (e) {
      TelemetryService.logException("PARSER_CRASH", e.toString());
      _cachedPageTexts.add(
        "A fatal parsing error occurred while reading this page block.",
      );
      await loadPageChunk(0);
    }
  }

  Future<void> loadPageChunk(int pageIndex) async {
    if (_isTransitioning || pageIndex >= _cachedPageTexts.length) return;
    _isTransitioning = true;

    try {
      _currentPageIndex = pageIndex;
      final Directory tempDir = await getTemporaryDirectory();
      final String expectedFilePath =
          '${tempDir.path}/${CacheManager.filePrefix}$_currentPageIndex.wav';

      if (_currentDocument != null) {
        final String fileName = _currentDocument!.path
            .split(Platform.pathSeparator)
            .last;
        await SessionManager.saveSession(fileName, _currentPageIndex);
      }

      String targetText = _cachedPageTexts[_currentPageIndex].trim();

      // FAULT TOLERANCE: Handle empty strings or blank scanning errors dynamically
      if (targetText.isEmpty) {
        targetText = "This page layout is empty or unparseable.";
      }

      File targetAudioFile = File(expectedFilePath);
      if (!await targetAudioFile.exists()) {
        try {
          await _ttsService.synthesizeTextToFile(
            targetText,
            "${CacheManager.filePrefix}$_currentPageIndex",
          );
        } catch (storageError) {
          TelemetryService.logException(
            "DISK_IO_FULL",
            storageError.toString(),
          );

          // Emergency Cache Flush: Wipe everything except the active workspace constraints
          await CacheManager.purgeAllCacheFiles();
          // Force a singular fallback execution retry
          await _ttsService.synthesizeTextToFile(
            targetText,
            "${CacheManager.filePrefix}$_currentPageIndex",
          );
        }
      }

      mediaItem.add(
        MediaItem(
          id: expectedFilePath,
          album: "Secure Reader Production Layer",
          title:
              "Reading Page ${_currentPageIndex + 1} of ${_cachedPageTexts.length}",
        ),
      );

      await _player.setAudioSource(AudioSource.file(targetAudioFile.path));
      await CacheManager.enforceSlidingWindow(_currentPageIndex);

      _triggerLookaheadWorker(_currentPageIndex + 1);
    } catch (criticalErr) {
      TelemetryService.logException(
        "AUDIO_PIPELINE_FAULT",
        criticalErr.toString(),
      );
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _triggerLookaheadWorker(int nextPageIndex) async {
    if (nextPageIndex >= _cachedPageTexts.length) return;

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String nextFilePath =
          '${tempDir.path}/${CacheManager.filePrefix}$nextPageIndex.wav';

      if (await File(nextFilePath).exists()) return;

      String nextText = _cachedPageTexts[nextPageIndex].trim();
      if (nextText.isEmpty) {
        nextText = "Next section contains unreadable assets.";
      }

      await _ttsService.synthesizeTextToFile(
        nextText,
        "${CacheManager.filePrefix}$nextPageIndex",
      );
    } catch (e) {
      // Isolate predictive engine anomalies cleanly to preserve foreground playback continuity
      TelemetryService.logException("LOOKAHEAD_SILENT_FAIL", e.toString());
    }
  }

  Future<void> _handlePageCompletion() async {
    final int nextPageIndex = _currentPageIndex + 1;
    if (nextPageIndex < _cachedPageTexts.length) {
      await loadPageChunk(nextPageIndex);
      play();
    } else {
      await stop();
    }
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() async => await _player.stop();
  
  /// Clean up resources when the audio handler is destroyed
  Future<void> dispose() async {
    await _processingStateSubscription?.cancel();
    await _player.dispose();
    await _ttsService.stop();
  }
  
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> skipToNext() async {
    await _handlePageCompletion();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentPageIndex > 0) {
      await loadPageChunk(_currentPageIndex - 1);
      play();
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
  }
}
