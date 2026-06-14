import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../../main.dart';
import '../models/sentence_block.dart';
import '../services/telemetry_service.dart';

class SentenceHighlightReader extends StatefulWidget {
  final String pageText;
  final Duration pageAudioDuration;

  const SentenceHighlightReader({
    super.key,
    required this.pageText,
    required this.pageAudioDuration,
  });

  @override
  State<SentenceHighlightReader> createState() =>
      _SentenceHighlightReaderState();
}

class _SentenceHighlightReaderState extends State<SentenceHighlightReader> {
  List<SentenceBlock>? _sentences;
  bool _isComputingTokens = true;
  final ValueNotifier<int> _activeSentenceIndexNotifier = ValueNotifier<int>(
    -1,
  );
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  StreamSubscription? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _compileTextMetadataAsync();
    _bindPositionPipeline();
  }

  /// Offloads regex matching and timing parsing to the long-lived Isolate
  Future<void> _compileTextMetadataAsync() async {
    final int startTimestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      final List<SentenceBlock> compiledBlocks = await globalIsolateWorker
          .computeSentenceTimings(widget.pageText, widget.pageAudioDuration);

      final int latency =
          DateTime.now().millisecondsSinceEpoch - startTimestamp;

      // Report metadata cleanly without capturing string payloads
      TelemetryService.logProfile(
        PerformanceMetrics(
          characterLength: widget.pageText.length,
          tokenCount: compiledBlocks.length,
          regexLatencyMs: latency,
          activeCacheSizeCount: globalAudioHandler.cachedPageTexts.length,
        ),
      );

      for (int i = 0; i < compiledBlocks.length; i++) {
        _itemKeys[i] = GlobalKey();
      }

      if (mounted) {
        setState(() {
          _sentences = compiledBlocks;
          _isComputingTokens = false;
        });
      }
    } catch (e) {
      TelemetryService.logException("MAPPING_PORT_FAILURE", e.toString());
      // Main-thread fallback logic execution continues down here...
    }
  }

  void _bindPositionPipeline() {
    // Monitor the background playback position tick rate
    _positionSubscription = AudioService.position.listen((
      Duration currentPosition,
    ) {
      final localSentences = _sentences;
      if (localSentences == null) {
        return; // Prevent parsing ticks prior to isolate layout initialization
      }

      int matchedIndex = -1;

      for (final sentence in localSentences) {
        if (currentPosition >= sentence.startOffset &&
            currentPosition <= sentence.endOffset) {
          matchedIndex = sentence.index;
          break;
        }
      }

      // Only update and trigger a repaint when a sentence boundary transition occurs
      if (matchedIndex != _activeSentenceIndexNotifier.value &&
          matchedIndex != -1) {
        _activeSentenceIndexNotifier.value = matchedIndex;
        _scrollToActiveSentence(matchedIndex);
      }
    });
  }

  void _scrollToActiveSentence(int index) {
    final targetKey = _itemKeys[index];
    if (targetKey == null || targetKey.currentContext == null) return;

    // Smoothly scroll the active text container safely into view without blocking the layout thread
    Scrollable.ensureVisible(
      targetKey.currentContext!,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      alignment: 0.3, // Keeps the active text centered in the viewport
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _scrollController.dispose();
    _activeSentenceIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UI Guard: Render a loading indicator while the background Isolate processes data strings
    if (_isComputingTokens || _sentences == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        itemCount: _sentences!.length,
        itemBuilder: (context, index) {
          final sentence = _sentences![index];
          return Padding(
            key: _itemKeys[index],
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: ValueListenableBuilder<int>(
              valueListenable: _activeSentenceIndexNotifier,
              builder: (context, activeIndex, _) {
                final bool isHighlighted = (activeIndex == index);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    sentence.text,
                    style: TextStyle(
                      fontSize: 18.0,
                      height: 1.5,
                      fontWeight: isHighlighted
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isHighlighted
                          ? Theme.of(context).primaryColor
                          : Theme.of(
                              context,
                            ).textTheme.bodyLarge?.color?.withValues(alpha: 0.85),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
