import 'dart:async';
import 'package:audio_session/audio_session.dart';

class AudioSessionManager {
  static StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  static StreamSubscription<void>? _becomingNoisySubscription;
  static Function()? _pauseCallback;
  static Function()? _playCallback;
  
  /// Initialize the audio session with pause/play callbacks
  static void setAudioCallbacks({
    required Function() onPause,
    required Function() onPlay,
  }) {
    _pauseCallback = onPause;
    _playCallback = onPlay;
  }
  
  /// Configures the hardware audio channels to respect phone calls and system alerts.
  static Future<void> configureMediaSession() async {
    final AudioSession session = await AudioSession.instance;

    // Configure for speech playback
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      ),
    );

    // Handle real-time hardware interruption events (e.g., incoming phone calls)
    _interruptionSubscription = session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            _pauseCallback?.call();
            break;
          case AudioInterruptionType.duck:
            // Ducking - pause audio for safety
            _pauseCallback?.call();
            break;
        }
      } else {
        // Interruption has ended, resume playback safely if it was interrupted
        if (event.type == AudioInterruptionType.pause) {
          _playCallback?.call();
        }
      }
    });

    // Handle headphone unplugs or Bluetooth disconnects (Become Noisy rule)
    _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) async {
      _pauseCallback?.call();
    });
  }

  /// Clean up audio session resources when app terminates
  static Future<void> dispose() async {
    await _interruptionSubscription?.cancel();
    await _becomingNoisySubscription?.cancel();
    _interruptionSubscription = null;
    _becomingNoisySubscription = null;
    _pauseCallback = null;
    _playCallback = null;
  }
}
