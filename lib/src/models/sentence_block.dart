class SentenceBlock {
  final int index;
  final String text;
  final Duration startOffset;
  final Duration endOffset;

  const SentenceBlock({
    required this.index,
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });
}

class PlaybackTimingEngine {
  /// Splits a raw text block into structural sentences and assigns
  /// proportional timestamp boundaries based on total audio file duration.
  static List<SentenceBlock> parsePage(String text, Duration totalDuration) {
    if (text.trim().isEmpty) return [];

    // Regex to capture standard sentence terminations (. ! ?) safely
    final RegExp sentenceRegex = RegExp(r'[^.!?]+([.!?]\s*|\$)');
    final Iterable<RegExpMatch> matches = sentenceRegex.allMatches(text);

    final List<String> rawSentences = matches
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (rawSentences.isEmpty) {
      rawSentences.add(text.trim());
    }

    final int totalCharacters = rawSentences.fold(
      0,
      (sum, s) => sum + s.length,
    );
    List<SentenceBlock> blocks = [];
    int accumulatedChars = 0;

    for (int i = 0; i < rawSentences.length; i++) {
      final String sentenceText = rawSentences[i];

      // Compute temporal markers proportionally based on data weight density
      final double startFraction = accumulatedChars / totalCharacters;
      accumulatedChars += sentenceText.length;
      final double endFraction = accumulatedChars / totalCharacters;

      final Duration startOffset = Duration(
        milliseconds: (totalDuration.inMilliseconds * startFraction).round(),
      );
      final Duration endOffset = Duration(
        milliseconds: (totalDuration.inMilliseconds * endFraction).round(),
      );

      blocks.add(
        SentenceBlock(
          index: i,
          text: sentenceText,
          startOffset: startOffset,
          endOffset: endOffset,
        ),
      );
    }

    return blocks;
  }
}
