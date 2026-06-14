import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../../main.dart'; 
import '../models/sentence_block.dart';

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
  late List<SentenceBlock> _sentences;
  final ValueNotifier<int> _activeSentenceIndexNotifier = ValueNotifier<int>(
    -1,
  );
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  StreamSubscription? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _compileTextMetadata();
    _bindPositionPipeline();
  }

  void _compileTextMetadata() {
    _sentences = PlaybackTimingEngine.parsePage(
      widget.pageText,
      widget.pageAudioDuration,
    );
    for (int i = 0; i < _sentences.length; i++) {
      _itemKeys[i] = GlobalKey();
    }
  }

  void _bindPositionPipeline() {
    // Monitor the background playback position tick rate
    _positionSubscription = AudioService.positionStream.listen((
      Duration currentPosition,
    ) {
      int matchedIndex = -1;

      for (final sentence in _sentences) {
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
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        itemCount: _sentences.length,
        itemBuilder: (context, index) {
          final sentence = _sentences[index];
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
                        ? Theme.of(context).primaryColor.withOpacity(0.12)
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
                            ).textTheme.bodyLarge?.color?.withOpacity(0.85),
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
