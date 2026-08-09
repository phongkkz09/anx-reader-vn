import 'dart:convert';
import 'package:anx_reader/config/shared_preference_provider.dart';

/// A single bookmark entry
class BookmarkEntry {
  final String url;
  final String title;
  final String chapterTitle;
  final double scrollPosition; // 0.0–1.0 fraction
  final int chapterIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  BookmarkEntry({
    required this.url,
    required this.title,
    this.chapterTitle = '',
    this.scrollPosition = 0.0,
    this.chapterIndex = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'chapterTitle': chapterTitle,
        'scrollPosition': scrollPosition,
        'chapterIndex': chapterIndex,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory BookmarkEntry.fromJson(Map<String, dynamic> json) {
    return BookmarkEntry(
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      chapterTitle: json['chapterTitle'] as String? ?? '',
      scrollPosition: (json['scrollPosition'] as num?)?.toDouble() ?? 0.0,
      chapterIndex: json['chapterIndex'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  BookmarkEntry copyWith({
    String? chapterTitle,
    double? scrollPosition,
    int? chapterIndex,
  }) {
    return BookmarkEntry(
      url: url,
      title: title,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Reading History entry
class HistoryEntry {
  final String url;
  final String title;
  final String chapterTitle;
  final DateTime readAt;
  final bool completed;

  HistoryEntry({
    required this.url,
    required this.title,
    this.chapterTitle = '',
    DateTime? readAt,
    this.completed = false,
  }) : readAt = readAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'chapterTitle': chapterTitle,
        'readAt': readAt.toIso8601String(),
        'completed': completed,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      chapterTitle: json['chapterTitle'] as String? ?? '',
      readAt: DateTime.tryParse(json['readAt'] ?? '') ?? DateTime.now(),
      completed: json['completed'] as bool? ?? false,
    );
  }
}

/// Bookmark Service
/// Manages bookmarks and reading history for Web Reader
class BookmarkService {
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  static const String _bookmarksKey = 'web_bookmarks';
  static const String _historyKey = 'web_reading_history';
  static const int _maxHistory = 200;

  List<BookmarkEntry> _bookmarks = [];
  List<HistoryEntry> _history = [];
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    final bmRaw = Prefs().prefs.getString(_bookmarksKey);
    if (bmRaw != null && bmRaw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(bmRaw);
        _bookmarks = list.map((j) => BookmarkEntry.fromJson(j)).toList();
      } catch (_) {
        _bookmarks = [];
      }
    }

    final hsRaw = Prefs().prefs.getString(_historyKey);
    if (hsRaw != null && hsRaw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(hsRaw);
        _history = list.map((j) => HistoryEntry.fromJson(j)).toList();
      } catch (_) {
        _history = [];
      }
    }

    _initialized = true;
  }

  Future<void> _saveBookmarks() async {
    final json = jsonEncode(_bookmarks.map((b) => b.toJson()).toList());
    await Prefs().prefs.setString(_bookmarksKey, json);
  }

  Future<void> _saveHistory() async {
    // Trim to max
    if (_history.length > _maxHistory) {
      _history = _history.sublist(_history.length - _maxHistory);
    }
    final json = jsonEncode(_history.map((h) => h.toJson()).toList());
    await Prefs().prefs.setString(_historyKey, json);
  }

  // === Bookmarks ===

  /// Save or update bookmark for a URL
  Future<void> saveBookmark({
    required String url,
    required String title,
    String chapterTitle = '',
    double scrollPosition = 0.0,
    int chapterIndex = 0,
  }) async {
    _bookmarks.removeWhere((b) => b.url == url);
    _bookmarks.add(BookmarkEntry(
      url: url,
      title: title,
      chapterTitle: chapterTitle,
      scrollPosition: scrollPosition,
      chapterIndex: chapterIndex,
    ));
    await _saveBookmarks();
  }

  /// Get bookmark for URL
  BookmarkEntry? getBookmark(String url) {
    return _bookmarks.where((b) => b.url == url).firstOrNull;
  }

  /// Remove bookmark
  Future<void> removeBookmark(String url) async {
    _bookmarks.removeWhere((b) => b.url == url);
    await _saveBookmarks();
  }

  /// Check if URL is bookmarked
  bool isBookmarked(String url) {
    return _bookmarks.any((b) => b.url == url);
  }

  /// All bookmarks (sorted by updated time)
  List<BookmarkEntry> get allBookmarks {
    final sorted = List<BookmarkEntry>.from(_bookmarks);
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  /// Bookmark count
  int get bookmarkCount => _bookmarks.length;

  // === Reading History ===

  /// Add to reading history
  Future<void> addHistory({
    required String url,
    required String title,
    String chapterTitle = '',
    bool completed = false,
  }) async {
    _history.removeWhere((h) => h.url == url);
    _history.add(HistoryEntry(
      url: url,
      title: title,
      chapterTitle: chapterTitle,
      completed: completed,
    ));
    await _saveHistory();
  }

  /// Mark as completed
  Future<void> markCompleted(String url) async {
    final idx = _history.indexWhere((h) => h.url == url);
    if (idx >= 0) {
      final old = _history[idx];
      _history[idx] = HistoryEntry(
        url: old.url,
        title: old.title,
        chapterTitle: old.chapterTitle,
        readAt: old.readAt,
        completed: true,
      );
      await _saveHistory();
    }
  }

  /// Get history for URL
  HistoryEntry? getHistory(String url) {
    return _history.where((h) => h.url == url).firstOrNull;
  }

  /// Clear history
  Future<void> clearHistory() async {
    _history.clear();
    await Prefs().prefs.remove(_historyKey);
  }

  /// All history (sorted by readAt, newest first)
  List<HistoryEntry> get allHistory {
    final sorted = List<HistoryEntry>.from(_history);
    sorted.sort((a, b) => b.readAt.compareTo(a.readAt));
    return sorted;
  }

  /// History count
  int get historyCount => _history.length;

  /// Completed count
  int get completedCount => _history.where((h) => h.completed).length;
}
