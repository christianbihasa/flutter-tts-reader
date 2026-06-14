import 'package:flutter/foundation.dart';

class PerformanceMetrics {
  final int characterLength;
  final int tokenCount;
  final int regexLatencyMs;
  final int activeCacheSizeCount;

  const PerformanceMetrics({
    required this.characterLength,
    required this.tokenCount,
    required this.regexLatencyMs,
    required this.activeCacheSizeCount,
  });
}

class TelemetryService {
  /// Emits metrics to debug consoles or lightweight analytics without violating user privacy
  static void logProfile(PerformanceMetrics metrics) {
    if (kReleaseMode) {
      // In production, route structured telemetry packets to your monitoring dashboard
      // Never attach the raw text strings to telemetry streams
      debugPrint(
        '📊 [METRIC] Len: ${metrics.characterLength} | Tokens: ${metrics.tokenCount} | Latency: ${metrics.regexLatencyMs}ms | CachedFiles: ${metrics.activeCacheSizeCount}',
      );
    } else {
      debugPrint(
        '🔧 [DEBUG-PERF] Latency Matrix calculated in ${metrics.regexLatencyMs} ms.',
      );
    }
  }

  static void logException(String anomalyCode, String message) {
    debugPrint('🚨 [TELEMETRY-CRITICAL] Code: $anomalyCode | Info: $message');
  }
}
