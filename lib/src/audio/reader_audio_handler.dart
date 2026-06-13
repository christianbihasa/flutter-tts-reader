import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../services/cache_manager.dart';

class ReaderAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  int _currentPageIndex = 0;
  bool _isTransitioning = false;

  ReaderAudioHandler() {
    _initPlayerStreams();
  }

  int get currentPageIndex => _currentPageIndex;

  void _initPlayerStreams() {
    // Pipeline player structural changes out into the system system broadcast stream hooks
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Monitor for track completion to fire Reactive Lookahead Transitions
    _player.processingStateStream.listen((processingState) async {
      if (processingState == ProcessingState.completed) {
        await _handlePageCompletion();
      }
    });
  }

  /// Programmatically triggers the loading sequence of a specific file page channel target
  Future<void> loadPageChunk(int pageIndex) async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    try {
      _currentPageIndex = pageIndex;
      final Directory tempDir = await getTemporaryDirectory();
      final String expectedFilePath =
          '${tempDir.path}/${CacheManager.filePrefix}$_currentPageIndex.wav';
      final File targetAudioFile = File(expectedFilePath);

      if (await targetAudioFile.exists()) {
        // Broadcast the active media control settings to the Lock Screen framework
        mediaItem.add(
          MediaItem(
            id: expectedFilePath,
            album: "TTS Reader Documents",
            title: "Reading Page ${_currentPageIndex + 1}",
            artist: "On-Device Engine",
          ),
        );

        // Source local file structures straight into the device hardware channels
        await _player.setAudioSource(AudioSource.file(targetAudioFile.path));

        // Trim storage boundaries right away upon layout initialization success
        await CacheManager.enforceSlidingWindow(_currentPageIndex);
      } else {
        // If the lookahead file isn't generated yet, halt until synthesis catches up
        await stop();
      }
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _handlePageCompletion() async {
    final int nextPageIndex = _currentPageIndex + 1;
    final Directory tempDir = await getTemporaryDirectory();
    final String nextFilePath =
        '${tempDir.path}/${CacheManager.filePrefix}$nextPageIndex.wav';

    if (await File(nextFilePath).exists()) {
      await loadPageChunk(nextPageIndex);
      play();
    } else {
      // Loop or stop if tracking limits are exceeded cleanly
      await stop();
    }
  }

  // --- Map Framework Lifecycle Controls directly to Native Buttons ---
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await playbackState.firstWhere(
      (state) => state.processingState == AudioProcessingState.idle,
    );
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

  /// Adapts internal just_audio pipeline payloads to standard AudioService structures
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
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
      queueIndex: event.currentIndex,
    );
  }
}
