import 'dart:async';
import 'dart:isolate';
import '../models/sentence_block.dart';

class IsolateRequest {
  final String text;
  final Duration duration;
  final SendPort replyPort;
  const IsolateRequest(this.text, this.duration, this.replyPort);
}

class TextIsolateWorker {
  late Isolate _isolate;
  late SendPort _sendPort;
  final Completer<void> _isolateReady = Completer<void>();

  /// Spawns the long-lived background isolate loop
  Future<void> start() async {
    final ReceivePort mainReceivePort = ReceivePort();

    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      mainReceivePort.sendPort,
    );

    mainReceivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        _isolateReady.complete();
      }
    });

    await _isolateReady.future;
  }

  /// Offloads the regex mapping tasks to the background isolate
  Future<List<SentenceBlock>> computeSentenceTimings(
    String text,
    Duration duration,
  ) async {
    await _isolateReady.future;
    final ReceivePort responsePort = ReceivePort();

    _sendPort.send(IsolateRequest(text, duration, responsePort.sendPort));

    final result = await responsePort.first;
    return result as List<SentenceBlock>;
  }

  /// The isolated threat loop execution entry point
  static void _isolateEntryPoint(SendPort mainSendPort) {
    final ReceivePort isolateReceivePort = ReceivePort();
    mainSendPort.send(isolateReceivePort.sendPort);

    isolateReceivePort.listen((message) {
      if (message is IsolateRequest) {
        // Run the complex character layout matrix parser entirely off the UI thread
        final List<SentenceBlock> compiledBlocks =
            PlaybackTimingEngine.parsePage(message.text, message.duration);
        message.replyPort.send(compiledBlocks);
      }
    });
  }

  void terminate() {
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }
}
