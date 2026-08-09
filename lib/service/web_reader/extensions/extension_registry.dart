import 'dart:convert';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/web_reader/extensions/source_extension.dart';

/// Extension Registry — manages all source extensions
/// Loads built-in + custom extensions, provides URL matching
class ExtensionRegistry {
  static final ExtensionRegistry _instance = ExtensionRegistry._internal();
  factory ExtensionRegistry() => _instance;
  ExtensionRegistry._internal();

  static const String _customKey = 'web_reader_extensions_custom';
  static const String _disabledKey = 'web_reader_extensions_disabled';

  List<SourceExtension> _customExtensions = [];
  Set<String> _disabledIds = {};

  /// All extensions (built-in + custom)
  List<SourceExtension> get all => [...builtIn, ..._customExtensions];

  /// Only enabled extensions
  List<SourceExtension> get enabled => all.where((e) => e.isEnabled).toList();

  /// Built-in extensions (Vietnamese + international sources)
  final List<SourceExtension> builtIn = [
    SourceExtension(
      id: 'truyenfull',
      name: 'TruyenFull',
      baseUrl: 'https://truyenfull.vn',
      contentSelector: '#list-chapter, .chapter-content',
      titleSelector: '.truyen-title, h1',
      chapterListSelector: '.list-chapter a',
      nextChapterSelector: 'a.btn-next, a[rel="next"]',
      prevChapterSelector: 'a.btn-prev, a[rel="prev"]',
      urlPatterns: ['truyenfull.vn/*'],
      isBuiltIn: true,
      author: 'AnxReader',
      description: 'Truyện Full — kho tàng truyện online lớn nhất Việt Nam',
      version: '1.2.0',
    ),
    SourceExtension(
      id: 'truyenqq',
      name: 'TruyenQQ',
      baseUrl: 'https://truyenqqvn.com',
      contentSelector: '.chapter-detail, .reading-detail',
      titleSelector: '.book-detail h1, h1.title',
      chapterListSelector: '.list-chapter a, .chapter-list a',
      urlPatterns: ['truyenqq*.com/*', 'truyenqqvn.com/*'],
      isBuiltIn: true,
      author: 'AnxReader',
      description: 'TruyenQQ — đọc truyện tranh online',
      version: '1.1.0',
    ),
    SourceExtension(
      id: 'nettruyen',
      name: 'NetTruyen',
      baseUrl: 'https://www.nettruyen.com',
      contentSelector: '.reading-detail .page-chapter',
      titleSelector: '.story-title h1, h1',
      chapterListSelector: '.list-chapter a',
      urlPatterns: ['nettruyen.com/*', 'nettruyenpro.com/*'],
      isBuiltIn: true,
      author: 'AnxReader',
      description: 'NetTruyen — truyện tranh online',
      version: '1.1.0',
    ),
    SourceExtension(
      id: 'blogtruyen',
      name: 'BlogTruyen',
      baseUrl: 'https://blogtruyen.vn',
      contentSelector: '.content-chapter, .body-chapter',
      titleSelector: 'h1.title, .story-title h1',
      chapterListSelector: '.list-chapter a',
      urlPatterns: ['blogtruyen.vn/*'],
      isBuiltIn: true,
      author: 'AnxReader',
      description: 'BlogTruyen — đọc truyện online',
      version: '1.0.0',
    ),
    SourceExtension(
      id: 'doctruyen3q',
      name: 'DocTruyen3Q',
      baseUrl: 'https://doctruyen3q.com',
      contentSelector: '.reading-content, .chapter-content',
      titleSelector: 'h1, .story-title',
      chapterListSelector: '.list-chapter a',
      urlPatterns: ['doctruyen3q.com/*'],
      isBuiltIn: true,
      author: 'AnxReader',
      description: 'DocTruyen3Q — đọc truyện tranh online',
      version: '1.0.0',
    ),
    SourceExtension(
      id: 'truyencv',
      name: 'TruyenCV',
      baseUrl: 'https://truyencv.com',
      contentSelector: '.chapter-content, .reading-content',
      titleSelector: 'h1.title, .story-title h1',
      chapterListSelector: '.list-chapter a',
      nextChapterSelector: 'a[rel="next"]',
      prevChapterSelector: 'a[rel="prev"]',
      urlPatterns: ['truyencv.com/*'],
      isBuiltIn: true,
      author: 'AnxReader',
      description: 'TruyenCV — đọc truyện online',
      version: '1.0.0',
    ),
    SourceExtension(
      id: 'wikipedia',
      name: 'Wikipedia',
      baseUrl: 'https://vi.wikipedia.org',
      contentSelector: '#mw-content-text, .mw-parser-output',
      titleSelector: '#firstHeading, h1.title',
      urlPatterns: ['*.wikipedia.org/*', 'wikipedia.org/*'],
      isBuiltIn: true,
      author: 'AnxReader',
      description: 'Wikipedia — bách khoa toàn thư',
      version: '1.0.0',
    ),
    SourceExtension(
      id: 'generic',
      name: 'Generic (any URL)',
      baseUrl: '',
      contentSelector: 'article, main, .content, .post, #content',
      titleSelector: 'h1, h2, .title',
      urlPatterns: ['*'],
      isBuiltIn: true,
      author: 'AnxReader',
      description: 'Trích xuất nội dung từ bất kỳ URL nào',
      version: '1.0.0',
    ),
  ];

  /// Load custom extensions from SharedPreferences
  void load() {
    // Load custom
    final customJson = Prefs().prefs.getString(_customKey);
    if (customJson != null && customJson.isNotEmpty) {
      try {
        final list = List<Map<String, dynamic>>.from(
          (jsonDecode(customJson) as List).cast<Map<String, dynamic>>(),
        );
        _customExtensions = list.map((j) => SourceExtension.fromJson(j)).toList();
      } catch (_) {
        _customExtensions = [];
      }
    }

    // Load disabled
    final disabledList = Prefs().prefs.getStringList(_disabledKey) ?? [];
    _disabledIds = disabledList.toSet();
  }

  /// Save custom extensions to SharedPreferences
  void _save() {
    Prefs().prefs.setString(
      _customKey,
      jsonEncode(_customExtensions.map((e) => e.toJson()).toList()),
    );
    Prefs().prefs.setStringList(_disabledKey, _disabledIds.toList());
  }

  /// Add a custom extension
  void addExtension(SourceExtension ext) {
    _customExtensions.removeWhere((e) => e.id == ext.id);
    _customExtensions.add(ext);
    _save();
  }

  /// Remove a custom extension
  void removeExtension(String id) {
    _customExtensions.removeWhere((e) => e.id == id);
    _disabledIds.remove(id);
    _save();
  }

  /// Toggle extension enabled/disabled
  void toggleExtension(String id, {bool? enabled}) {
    final ext = getExtensionById(id);
    if (ext == null) return;

    final shouldEnable = enabled ?? _disabledIds.contains(id);
    if (shouldEnable) {
      _disabledIds.remove(id);
    } else {
      _disabledIds.add(id);
    }
    _save();
  }

  /// Get extension by ID
  SourceExtension? getExtensionById(String id) {
    return all.firstWhere(
      (e) => e.id == id,
      orElse: () => all.first,
    );
  }

  /// Auto-detect extension for a URL
  SourceExtension? detectSource(String url) {
    for (final ext in enabled) {
      if (ext.matchesUrl(url)) return ext;
    }
    // Fallback to generic
    return enabled.firstWhere(
      (e) => e.id == 'generic',
      orElse: () => enabled.first,
    );
  }

  /// Search extensions by name/description
  List<SourceExtension> search(String query) {
    final q = query.toLowerCase();
    return all.where((e) =>
      e.name.toLowerCase().contains(q) ||
      e.description.toLowerCase().contains(q) ||
      e.baseUrl.toLowerCase().contains(q)
    ).toList();
  }

  /// Import extensions from JSON string
  int importFromJson(String jsonString) {
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      int imported = 0;
      for (final item in list) {
        final ext = SourceExtension.fromJson(item as Map<String, dynamic>);
        if (ext.id.isNotEmpty && ext.baseUrl.isNotEmpty) {
          addExtension(ext);
          imported++;
        }
      }
      return imported;
    } catch (_) {
      return 0;
    }
  }

  /// Export all custom extensions as JSON string
  String exportToJson() {
    return jsonEncode(_customExtensions.map((e) => e.toJson()).toList());
  }

  /// Get count of enabled extensions
  int get enabledCount => enabled.length;

  /// Get count of custom extensions
  int get customCount => _customExtensions.length;
}
