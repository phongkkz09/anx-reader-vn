import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';

/// Cached content item
class CacheItem {
  final String url;
  final String title;
  final String content;
  final String sourceId;
  final DateTime cachedAt;
  final DateTime lastAccessed;
  final int accessCount;
  final int sizeBytes;

  CacheItem({
    required this.url,
    required this.title,
    required this.content,
    this.sourceId = '',
    DateTime? cachedAt,
    DateTime? lastAccessed,
    this.accessCount = 1,
  })  : cachedAt = cachedAt ?? DateTime.now(),
        lastAccessed = lastAccessed ?? DateTime.now(),
        sizeBytes = utf8.encode(title + content).length;

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'content': content,
        'sourceId': sourceId,
        'cachedAt': cachedAt.toIso8601String(),
        'lastAccessed': lastAccessed.toIso8601String(),
        'accessCount': accessCount,
        'sizeBytes': sizeBytes,
      };

  factory CacheItem.fromJson(Map<String, dynamic> json) {
    return CacheItem(
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
      cachedAt: DateTime.tryParse(json['cachedAt'] ?? '') ?? DateTime.now(),
      lastAccessed: DateTime.tryParse(json['lastAccessed'] ?? '') ?? DateTime.now(),
      accessCount: json['accessCount'] as int? ?? 1,
    );
  }
}

/// Cache statistics
class CacheStats {
  final int itemCount;
  final int totalSizeKB;
  final DateTime? oldestItem;
  final DateTime? newestItem;

  const CacheStats({
    required this.itemCount,
    required this.totalSizeKB,
    required this.oldestItem,
    required this.newestItem,
  });
}

/// Content Cache Service
/// Stores extracted web content for offline reading
class ContentCacheService {
  static final ContentCacheService _instance = ContentCacheService._internal();
  factory ContentCacheService() => _instance;
  ContentCacheService._internal();

  static const String _cacheKey = 'web_content_cache';
  static const String _maxSizeKey = 'web_cache_max_items';
  static const int _defaultMaxItems = 100;
  static const Duration _defaultMaxAge = Duration(days: 30);

  List<CacheItem> _cache = [];
  bool _initialized = false;

  /// Initialize cache from SharedPreferences
  Future<void> init() async {
    if (_initialized) return;

    final raw = Prefs().prefs.getString(_cacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        _cache = list.map((j) => CacheItem.fromJson(j as Map<String, dynamic>)).toList();
      } catch (_) {
        _cache = [];
      }
    }

    _initialized = true;
  }

  /// Save cache to SharedPreferences
  Future<void> _save() async {
    try {
      final json = jsonEncode(_cache.map((c) => c.toJson()).toList());
      await Prefs().prefs.setString(_cacheKey, json);
    } catch (_) {
      // Storage full or invalid — clear oldest items
      _cache = _cache.take(_cache.length ~/ 2).toList();
      final json = jsonEncode(_cache.map((c) => c.toJson()).toList());
      await Prefs().prefs.setString(_cacheKey, json);
    }
  }

  /// Get cached content for URL
  CacheItem? get(String url) {
    final item = _cache.where((c) => c.url == url).firstOrNull;
    if (item != null) {
      // Update access time and count
      _cache.remove(item);
      _cache.add(CacheItem(
        url: item.url,
        title: item.title,
        content: item.content,
        sourceId: item.sourceId,
        cachedAt: item.cachedAt,
        lastAccessed: DateTime.now(),
        accessCount: item.accessCount + 1,
      ));
      _save();
    }
    return item;
  }

  /// Cache content
  Future<void> put({
    required String url,
    required String title,
    required String content,
    String sourceId = '',
  }) async {
    // Remove existing entry for same URL
    _cache.removeWhere((c) => c.url == url);

    // Add new entry
    _cache.add(CacheItem(
      url: url,
      title: title,
      content: content,
      sourceId: sourceId,
    ));

    // Enforce max items limit
    final maxItems = Prefs().prefs.getInt(_maxSizeKey) ?? _defaultMaxItems;
    while (_cache.length > maxItems) {
      // Remove least recently accessed
      _cache.sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));
      _cache.removeAt(0);
    }

    await _save();
  }

  /// Check if URL is cached
  bool contains(String url) {
    return _cache.any((c) => c.url == url);
  }

  /// Remove specific cache entry
  Future<void> remove(String url) async {
    _cache.removeWhere((c) => c.url == url);
    await _save();
  }

  /// Clear all cache
  Future<void> clear() async {
    _cache.clear();
    await Prefs().prefs.remove(_cacheKey);
  }

  /// Auto-cleanup old entries
  Future<void> cleanup({Duration? maxAge}) async {
    final age = maxAge ?? _defaultMaxAge;
    final cutoff = DateTime.now().subtract(age);
    final before = _cache.length;
    _cache.removeWhere((c) => c.cachedAt.isBefore(cutoff));
    if (_cache.length != before) {
      await _save();
    }
  }

  /// Get all cached items (sorted by last accessed)
  List<CacheItem> get all {
    final sorted = List<CacheItem>.from(_cache);
    sorted.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
    return sorted;
  }

  /// Search cache by title or content
  List<CacheItem> search(String query) {
    final q = query.toLowerCase();
    return _cache
        .where((c) =>
            c.title.toLowerCase().contains(q) ||
            c.content.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
  }

  /// Get cache statistics
  CacheStats getStats() {
    if (_cache.isEmpty) {
      return const CacheStats(
        itemCount: 0,
        totalSizeKB: 0,
        oldestItem: null,
        newestItem: null,
      );
    }

    int totalBytes = 0;
    DateTime oldest = DateTime.now();
    DateTime newest = DateTime(2000);

    for (final item in _cache) {
      totalBytes += item.sizeBytes;
      if (item.cachedAt.isBefore(oldest)) oldest = item.cachedAt;
      if (item.cachedAt.isAfter(newest)) newest = item.cachedAt;
    }

    return CacheStats(
      itemCount: _cache.length,
      totalSizeKB: totalBytes ~/ 1024,
      oldestItem: oldest,
      newestItem: newest,
    );
  }

  /// Set max cache items
  void setMaxItems(int max) {
    Prefs().prefs.setInt(_maxSizeKey, max.clamp(10, 500));
  }

  /// Get max cache items
  int get maxItems => Prefs().prefs.getInt(_maxSizeKey) ?? _defaultMaxItems;

  /// Get total items count
  int get count => _cache.length;
}
