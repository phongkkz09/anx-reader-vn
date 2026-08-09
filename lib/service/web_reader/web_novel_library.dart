import 'dart:convert';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/web_reader/web_content_extractor.dart';
import 'package:anx_reader/service/web_reader/download_manager.dart';

/// Model for a web novel item in library
class WebNovelItem {
  final String id;
  final String title;
  final String url;
  final String? coverUrl;
  final String? author;
  final String? description;
  final String sourceName;
  final DateTime addedAt;
  final DateTime lastReadAt;
  final int totalChapters;
  final int lastChapterIndex;
  final bool isFavorite;
  final bool autoUpdate;
  
  WebNovelItem({
    required this.id,
    required this.title,
    required this.url,
    this.coverUrl,
    this.author,
    this.description,
    required this.sourceName,
    DateTime? addedAt,
    DateTime? lastReadAt,
    this.totalChapters = 0,
    this.lastChapterIndex = 0,
    this.isFavorite = false,
    this.autoUpdate = true,
  }) : addedAt = addedAt ?? DateTime.now(),
       lastReadAt = lastReadAt ?? DateTime.now();
  
  /// Get reading progress as fraction (0.0 - 1.0)
  double get progress {
    if (totalChapters <= 0) return 0.0;
    return (lastChapterIndex + 1) / totalChapters;
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'coverUrl': coverUrl,
    'author': author,
    'description': description,
    'sourceName': sourceName,
    'addedAt': addedAt.toIso8601String(),
    'lastReadAt': lastReadAt.toIso8601String(),
    'totalChapters': totalChapters,
    'lastChapterIndex': lastChapterIndex,
    'isFavorite': isFavorite,
    'autoUpdate': autoUpdate,
  };
  
  factory WebNovelItem.fromJson(Map<String, dynamic> json) => WebNovelItem(
    id: json['id'],
    title: json['title'],
    url: json['url'],
    coverUrl: json['coverUrl'],
    author: json['author'],
    description: json['description'],
    sourceName: json['sourceName'],
    addedAt: DateTime.parse(json['addedAt']),
    lastReadAt: DateTime.parse(json['lastReadAt']),
    totalChapters: json['totalChapters'] ?? 0,
    lastChapterIndex: json['lastChapterIndex'] ?? 0,
    isFavorite: json['isFavorite'] ?? false,
    autoUpdate: json['autoUpdate'] ?? true,
  );
  
  WebNovelItem copyWith({
    String? title,
    String? coverUrl,
    String? author,
    String? description,
    DateTime? lastReadAt,
    int? totalChapters,
    int? lastChapterIndex,
    bool? isFavorite,
    bool? autoUpdate,
  }) => WebNovelItem(
    id: id,
    title: title ?? this.title,
    url: url,
    coverUrl: coverUrl ?? this.coverUrl,
    author: author ?? this.author,
    description: description ?? this.description,
    sourceName: sourceName,
    addedAt: addedAt,
    lastReadAt: lastReadAt ?? this.lastReadAt,
    totalChapters: totalChapters ?? this.totalChapters,
    lastChapterIndex: lastChapterIndex ?? this.lastChapterIndex,
    isFavorite: isFavorite ?? this.isFavorite,
    autoUpdate: autoUpdate ?? this.autoUpdate,
  );
}

/// Web Novel Library Service
/// Manages reading list, progress, update tracking for web novels
class WebNovelLibrary {
  static final WebNovelLibrary _instance = WebNovelLibrary._internal();
  factory WebNovelLibrary() => _instance;
  
  WebNovelLibrary._internal();
  
  List<WebNovelItem> _items = [];
  final Map<String, List<WebChapter>> _chapterCache = {};
  
  List<WebNovelItem> get items => List.unmodifiable(_items);
  List<WebNovelItem> get favorites => _items.where((i) => i.isFavorite).toList();
  
  /// Load library from SharedPreferences
  void load() {
    final data = Prefs().prefs.getString('web_novel_library');
    if (data == null || data.isEmpty) {
      _items = [];
      return;
    }
    try {
      final list = List<Map<String, dynamic>>.from(
        (jsonDecode(data) as List).cast<Map<String, dynamic>>(),
      );
      _items = list.map((j) => WebNovelItem.fromJson(j)).toList();
    } catch (e) {
      _items = [];
    }
  }
  
  /// Save library to SharedPreferences
  void _save() {
    final data = jsonEncode(_items.map((i) => i.toJson()).toList());
    Prefs().prefs.setString('web_novel_library', data);
  }
  
  /// Add a web novel to library
  Future<void> addNovel(WebNovelItem item) async {
    // Deduplicate by URL
    _items.removeWhere((i) => i.url == item.url);
    _items.insert(0, item);
    _save();
  }
  
  /// Remove a web novel
  void removeNovel(String id) {
    _items.removeWhere((i) => i.id == id);
    _chapterCache.remove(id);
    _save();
  }
  
  /// Update reading progress
  void updateProgress({
    required String id,
    required int chapterIndex,
    required int totalChapters,
  }) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    
    _items[index] = _items[index].copyWith(
      lastChapterIndex: chapterIndex,
      totalChapters: totalChapters,
      lastReadAt: DateTime.now(),
    );
    _save();
  }
  
  /// Toggle favorite
  void toggleFavorite(String id) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    
    _items[index] = _items[index].copyWith(
      isFavorite: !_items[index].isFavorite,
    );
    _save();
  }
  
  /// Toggle auto update
  void toggleAutoUpdate(String id) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    
    _items[index] = _items[index].copyWith(
      autoUpdate: !_items[index].autoUpdate,
    );
    _save();
  }
  
  /// Get novel by ID
  WebNovelItem? getById(String id) {
    return _items.where((i) => i.id == id).firstOrNull;
  }
  
  /// Get novel by URL
  WebNovelItem? getByUrl(String url) {
    return _items.where((i) => i.url == url).firstOrNull;
  }
  
  /// Check if URL is already in library
  bool isTracked(String url) {
    return _items.any((i) => i.url == url);
  }
  
  /// Check for chapter updates for all tracked novels
  Future<List<WebNovelUpdate>> checkUpdates() async {
    final updates = <WebNovelUpdate>[];
    final extractor = WebContentExtractor();
    
    for (final item in _items) {
      if (!item.autoUpdate) continue;
      
      try {
        final content = await extractor.extractContent(item.url);
        
        if (content.chapters.isNotEmpty && 
            content.currentChapterIndex > item.lastChapterIndex) {
          final newChapters = content.currentChapterIndex - item.lastChapterIndex;
          updates.add(WebNovelUpdate(
            novelId: item.id,
            novelTitle: item.title,
            newChapters: newChapters,
            latestChapterTitle: content.title,
            latestUrl: content.nextChapterUrl ?? item.url,
          ));
          
          // Update total chapters count
          final index = _items.indexWhere((i) => i.id == item.id);
          if (index >= 0) {
            _items[index] = _items[index].copyWith(
              totalChapters: content.chapters.length,
            );
          }
        }
      } catch (e) {
        // Skip failed checks silently
      }
    }
    
    _save();
    return updates;
  }
  
  /// Search novels in library
  List<WebNovelItem> search(String query) {
    final q = query.toLowerCase();
    return _items.where((i) => 
      i.title.toLowerCase().contains(q) ||
      (i.author?.toLowerCase().contains(q) ?? false) ||
      i.sourceName.toLowerCase().contains(q)
    ).toList();
  }
  
  /// Sort novels
  List<WebNovelItem> sort(SortOption option, {bool ascending = true}) {
    final sorted = List<WebNovelItem>.from(_items);
    
    switch (option) {
      case SortOption.title:
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.lastRead:
        sorted.sort((a, b) => a.lastReadAt.compareTo(b.lastReadAt));
        break;
      case SortOption.progress:
        sorted.sort((a, b) => a.progress.compareTo(b.progress));
        break;
      case SortOption.source:
        sorted.sort((a, b) => a.sourceName.compareTo(b.sourceName));
        break;
    }
    
    if (!ascending) sorted.reverse;
    return sorted;
  }
  
  /// Get statistics
  LibraryStats get stats => LibraryStats(
    totalNovels: _items.length,
    favoritesCount: favorites.length,
    totalChaptersRead: _items.fold(0, (sum, i) => sum + i.lastChapterIndex + 1),
    readingNovels: _items.where((i) => i.progress > 0 && i.progress < 1).length,
  );
}

enum SortOption { title, lastRead, progress, source }

class WebNovelUpdate {
  final String novelId;
  final String novelTitle;
  final int newChapters;
  final String latestChapterTitle;
  final String latestUrl;
  
  const WebNovelUpdate({
    required this.novelId,
    required this.novelTitle,
    required this.newChapters,
    required this.latestChapterTitle,
    required this.latestUrl,
  });
}

class LibraryStats {
  final int totalNovels;
  final int favoritesCount;
  final int totalChaptersRead;
  final int readingNovels;
  
  const LibraryStats({
    required this.totalNovels,
    required this.favoritesCount,
    required this.totalChaptersRead,
    required this.readingNovels,
  });
}
