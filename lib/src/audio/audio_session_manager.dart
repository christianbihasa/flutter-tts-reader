import 'package:audio_session/audio_session.dart';
import '../../main.dart';

class AudioSessionManager {
  /// Configures the hardware audio channels to respect phone calls and system alerts.
  static Future<void> configureMediaSession() async {
    final AudioSession session = await AudioSession.instance;

    // Optimize the device hardware layout specifically for speech audio streams
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioFocusGain: AudioFocusGain.g1, // Request definitive main focus
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.media,
        ),
        androidWillPauseWhenDucked:
            true, // Forces a hard pause instead of turning volume down
      ),
    );

    // Handle real-time hardware interruption events (e.g., incoming phone calls)
    session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            await globalAudioHandler.pause();
            break;
          case AudioInterruptionType.duck:
            // Handled by androidWillPauseWhenDucked, but duplicated here for platform security
            await globalAudioHandler.pause();
            break;
        }
      } else {
        // Interruption has ended, resume playback safely if it was interrupted
        if (event.type == AudioInterruptionType.pause) {
          await globalAudioHandler.play();
        }
      }
    });

    // Handle headphone unplugs or Bluetooth disconnects (Become Noisy rule)
    session.becomingNoisyEventStream.listen((_) async {
      await globalAudioHandler.pause();
    });
  }
}
