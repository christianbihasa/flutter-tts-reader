import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'src/audio/reader_audio_handler.dart';

// Declare a global reference to the audio pipeline handler configuration
late ReaderAudioHandler globalAudioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bind your specialized audio logic explicitly to the OS foreground daemon structures
  globalAudioHandler = await AudioService.init<ReaderAudioHandler>(
    builder: () => ReaderAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId:
          'io.github.christianbihasa.flutter_tts_reader.channel.audio',
      androidNotificationChannelName: 'Ebook Reader Audio Service Flow',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter TTS Reader',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const Scaffold(
        body: Center(child: Text('Flutter TTS Reader')),
      ),
    );
  }
}
