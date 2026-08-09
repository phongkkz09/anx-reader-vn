import 'dart:async';
import 'package:anx_reader/service/web_reader/web_novel_library.dart';
import 'package:anx_reader/service/web_reader/web_content_extractor.dart';

/// Update check result
class UpdateResult {
  final List<WebNovelUpdate> updates;
  final DateTime checkedAt;
  final int novelsChecked;
  final int errorsCount;

  const UpdateResult({
    required this.updates,
    required this.checkedAt,
    required this.novelsChecked,
    this.errorsCount = 0,
  });

  bool get hasUpdates => updates.isNotEmpty;
  int get totalNewChapters => updates.fold(0, (sum, u) => sum + u.newChapters);
}

/// Update Checker Service
/// Periodically checks tracked novels for new chapters
class UpdateChecker {
  static final UpdateChecker _instance = UpdateChecker._internal();
  factory UpdateChecker() => _instance;

  UpdateChecker._internal();

  final WebNovelLibrary _library = WebNovelLibrary();
  Timer? _timer;
  Duration _checkInterval = const Duration(hours: 6);
  DateTime? _lastCheckTime;

  final _updateController = StreamController<UpdateResult>.broadcast();
  Stream<UpdateResult> get updateStream => _updateController.stream;

  /// Get last check time
  DateTime? get lastCheckTime => _lastCheckTime;

  /// Get check interval
  Duration get checkInterval => _checkInterval;

  /// Set check interval (minimum 1 hour)
  void setCheckInterval(Duration interval) {
    _checkInterval = Duration(
      hours: interval.inHours.clamp(1, 24),
    );
    _restartTimer();
  }

  /// Start periodic update checks
  void startPeriodicCheck() {
    _timer?.cancel();
    _timer = Timer.periodic(_checkInterval, (_) => checkForUpdates());
  }

  /// Stop periodic checks
  void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
  }

  /// Restart timer with new interval
  void _restartTimer() {
    if (_timer != null) {
      startPeriodicCheck();
    }
  }

  /// Check for updates now
  Future<UpdateResult> checkForUpdates() async {
    _library.load();

    final updates = <WebNovelUpdate>[];
    final extractor = WebContentExtractor();
    int checked = 0;
    int errors = 0;

    for (final item in _library.items) {
      if (!item.autoUpdate) continue;

      try {
        checked++;
        final content = await extractor.extractContent(item.url);

        if (content.chapters.isNotEmpty) {
          final newChapterCount = content.chapters.length;
          final knownChapterCount = item.totalChapters;

          if (newChapterCount > knownChapterCount) {
            updates.add(WebNovelUpdate(
              novelId: item.id,
              novelTitle: item.title,
              newChapters: newChapterCount - knownChapterCount,
              latestChapterTitle: content.chapters.last.title,
              latestUrl: content.chapters.last.url,
            ));

            // Update novel in library with new chapter count
            _library.updateProgress(
              id: item.id,
              chapterIndex: item.lastChapterIndex,
              totalChapters: newChapterCount,
            );
          }
        }

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        errors++;
        // Continue checking other novels even if one fails
      }
    }

    final result = UpdateResult(
      updates: updates,
      checkedAt: DateTime.now(),
      novelsChecked: checked,
      errorsCount: errors,
    );

    _lastCheckTime = result.checkedAt;
    _updateController.add(result);

    return result;
  }

  /// Check single novel for updates
  Future<WebNovelUpdate?> checkNovel(String novelId) async {
    final item = _library.getById(novelId);
    if (item == null) return null;

    try {
      final extractor = WebContentExtractor();
      final content = await extractor.extractContent(item.url);

      if (content.chapters.isNotEmpty) {
        final newChapterCount = content.chapters.length;
        final knownChapterCount = item.totalChapters;

        if (newChapterCount > knownChapterCount) {
          _library.updateProgress(
            id: item.id,
            chapterIndex: item.lastChapterIndex,
            totalChapters: newChapterCount,
          );

          return WebNovelUpdate(
            novelId: item.id,
            novelTitle: item.title,
            newChapters: newChapterCount - knownChapterCount,
            latestChapterTitle: content.chapters.last.title,
            latestUrl: content.chapters.last.url,
          );
        }
      }
    } catch (e) {
      // Return null on error
    }

    return null;
  }

  /// Dispose
  void dispose() {
    stopPeriodicCheck();
    _updateController.close();
  }
}
