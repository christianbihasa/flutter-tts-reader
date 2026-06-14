import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../services/cache_manager.dart';
import '../services/session_manager.dart';
import '../parser/pdf_parser_service.dart';
import '../audio/system_tts_service.dart';

class ReaderAudioHandler extends BaseAudioHandler
    with QueueHandler, PlaybackHandler {
  final AudioPlayer _player = AudioPlayer();
  final PdfParserService _parser = PdfParserService();
  final SystemTtsService _tts = SystemTtsService();

  File? _currentDocument;
  List<String> _cachedPageTexts = [];
  int _currentPageIndex = 0;
  bool _isTransitioning = false;

  ReaderAudioHandler() {
    _initPlayerStreams();
  }

  int get currentPageIndex => _currentPageIndex;
  List<String> get cachedPageTexts => _cachedPageTexts;

  void _initPlayerStreams() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    _player.processingStateStream.listen((processingState) async {
      if (processingState == ProcessingState.completed) {
        await _handlePageCompletion();
      }
    });
  }

  /// Registers and processes a document workspace target.
  Future<void> initializeDocument(File file, int initialPage) async {
    _currentDocument = file;
    _currentPageIndex = initialPage;

    // Load text blocks into memory to optimize processing on lower-end CPUs
    _cachedPageTexts.clear();
    await for (final pageText in _parser.parseFilePageByPage(file)) {
      _cachedPageTexts.add(pageText);
    }

    await _tts.initialize();
    await loadPageChunk(_currentPageIndex);
  }

  Future<void> loadPageChunk(int pageIndex) async {
    if (_isTransitioning ||
        _currentDocument == null ||
        pageIndex >= _cachedPageTexts.length)
      return;
    _isTransitioning = true;

    try {
      _currentPageIndex = pageIndex;
      final Directory tempDir = await getTemporaryDirectory();
      final String expectedFilePath =
          '${tempDir.path}/${CacheManager.filePrefix}$_currentPageIndex.wav';

      // 1. Enforce reactive save state whenever the user transitions tracks
      final String fileName = _currentDocument!.path
          .split(Platform.pathSeparator)
          .last;
      await SessionManager.saveSession(fileName, _currentPageIndex);

      // 2. Ensure current asset exists. If not, construct it instantly (Cold Start recovery)
      File targetAudioFile = File(expectedFilePath);
      if (!await targetAudioFile.exists()) {
        await _tts.synthesizeTextToFile(
          _cachedPageTexts[_currentPageIndex],
          "${CacheManager.filePrefix}$_currentPageIndex",
        );
      }

      mediaItem.add(
        MediaItem(
          id: expectedFilePath,
          album: "TTS Reader Library",
          title:
              "Reading Page ${_currentPageIndex + 1} of ${_cachedPageTexts.length}",
          artist: "On-Device Engine",
        ),
      );

      await _player.setAudioSource(AudioSource.file(targetAudioFile.path));
      await CacheManager.enforceSlidingWindow(_currentPageIndex);

      // 3. OPTIMAL DECISION: Fire isolated background pre-synthesis worker for Page N + 1
      _triggerLookaheadWorker(_currentPageIndex + 1);
    } finally {
      _isTransitioning = false;
    }
  }

  /// Predictive lookahead synthesizes the next track ahead of time.
  Future<void> _triggerLookaheadWorker(int nextPageIndex) async {
    if (nextPageIndex >= _cachedPageTexts.length) return;

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String nextFilePath =
          '${tempDir.path}/${CacheManager.filePrefix}$nextPageIndex.wav';
      final File lookaheadFile = File(nextFilePath);

      // If already pre-cached by sliding window parameters, skip processing entirely
      if (await lookaheadFile.exists()) return;

      // Silently synthesize next text bundle straight to storage background channels
      await _tts.synthesizeTextToFile(
        _cachedPageTexts[nextPageIndex],
        "${CacheManager.filePrefix}$nextPageIndex",
      );
    } catch (_) {
      // Isolate failures to protect active foreground playback stability
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
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> skipToNext() async => await _handlePageCompletion();
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
