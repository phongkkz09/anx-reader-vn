import 'dart:async';
import 'package:anx_reader/config/shared_preference_provider.dart';

/// Pronunciation dictionary entry
class PronunciationEntry {
  final String original;
  final String replacement;

  PronunciationEntry({
    required this.original,
    required this.replacement,
  });

  Map<String, dynamic> toJson() => {
        'original': original,
        'replacement': replacement,
      };

  factory PronunciationEntry.fromJson(Map<String, dynamic> json) {
    return PronunciationEntry(
      original: json['original'] as String? ?? '',
      replacement: json['replacement'] as String? ?? '',
    );
  }
}

/// Web Reader settings service
/// Manages sleep timer, playback speed, and pronunciation dictionary
class WebReaderSettings {
  static final WebReaderSettings _instance = WebReaderSettings._internal();

  factory WebReaderSettings() => _instance;

  WebReaderSettings._internal();

  // --- Sleep Timer ---
  Timer? _sleepTimer;
  DateTime? _sleepEndTime;
  final List<VoidCallback> _onSleepTimerEnd = [];

  /// Add callback for when sleep timer ends
  void addSleepTimerListener(VoidCallback callback) {
    _onSleepTimerEnd.add(callback);
  }

  /// Remove callback
  void removeSleepTimerListener(VoidCallback callback) {
    _onSleepTimerEnd.remove(callback);
  }

  /// Start sleep timer with countdown duration
  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepEndTime = DateTime.now().add(duration);

    _sleepTimer = Timer(duration, () {
      _sleepTimer = null;
      _sleepEndTime = null;
      for (final callback in _onSleepTimerEnd) {
        callback();
      }
    });
  }

  /// Start sleep timer to stop after N chapters
  void startSleepTimerAfterChapters(int chapters) {
    _sleepTimer?.cancel();
    _chaptersRemaining = chapters;
    _sleepEndTime = null;
  }

  int _chaptersRemaining = 0;

  /// Decrement chapter counter (called when chapter changes)
  void chapterChanged() {
    if (_chaptersRemaining > 0) {
      _chaptersRemaining--;
      if (_chaptersRemaining == 0) {
        for (final callback in _onSleepTimerEnd) {
          callback();
        }
      }
    }
  }

  /// Get remaining sleep time
  Duration? get remainingSleepTime {
    if (_sleepEndTime == null) return null;
    final remaining = _sleepEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Get remaining chapters for sleep timer
  int get remainingChapters => _chaptersRemaining;

  /// Is sleep timer active?
  bool get isSleepTimerActive => _sleepTimer != null || _chaptersRemaining > 0;

  /// Cancel sleep timer
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndTime = null;
    _chaptersRemaining = 0;
  }

  // --- Playback Speed ---
  /// Get playback speed
  double get playbackSpeed => Prefs().ttsRate;

  /// Set playback speed (0.5x - 4.0x)
  void setPlaybackSpeed(double speed) {
    if (speed < 0.5) speed = 0.5;
    if (speed > 4.0) speed = 4.0;
    Prefs().ttsRate = speed;
  }

  // --- Pronunciation Dictionary ---
  static const String _pronunciationsKey = 'web_reader_pronunciations';

  /// Get all pronunciation entries
  List<PronunciationEntry> get pronunciations {
    final raw = Prefs().prefs.getString(_pronunciationsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      // Parse the JSON-like string list
      final decoded = _parseStringList(raw);
      return decoded
          .map((e) => PronunciationEntry.fromJson(e))
          .where((e) => e.original.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Parse a Dart-style list string to list of maps
  List<Map<String, dynamic>> _parseStringList(String raw) {
    // Format: [{original: x, replacement: y}, ...]
    final result = <Map<String, dynamic>>[];
    final entries = RegExp(r'\{([^}]*)\}').allMatches(raw);

    for (final match in entries) {
      final content = match.group(1) ?? '';
      final map = <String, dynamic>{};
      for (final pair in RegExp(r'(\w+):\s*([^,]+)').allMatches(content)) {
        map[pair.group(1)!] = pair.group(2)!.trim().replaceAll("'", '');
      }
      if (map.isNotEmpty) result.add(map);
    }

    return result;
  }

  /// Add pronunciation entry
  void addPronunciation(String original, String replacement) {
    final entries = pronunciations;
    // Remove existing entry for same original
    entries.removeWhere((e) => e.original == original);
    entries.add(PronunciationEntry(original: original, replacement: replacement));
    _savePronunciations(entries);
  }

  /// Remove pronunciation entry
  void removePronunciation(String original) {
    final entries = pronunciations;
    entries.removeWhere((e) => e.original == original);
    _savePronunciations(entries);
  }

  void _savePronunciations(List<PronunciationEntry> entries) {
    final jsonList = entries.map((e) => e.toJson()).toList();
    Prefs().prefs.setString(_pronunciationsKey, jsonList.toString());
  }

  /// Apply pronunciation dictionary to text
  String applyPronunciations(String text) {
    final entries = pronunciations;
    if (entries.isEmpty) return text;

    var result = text;
    for (final entry in entries) {
      if (entry.original.isNotEmpty) {
        result = result.replaceAll(entry.original, entry.replacement);
      }
    }
    return result;
  }
}

/// Callback typedef
typedef VoidCallback = void Function();
