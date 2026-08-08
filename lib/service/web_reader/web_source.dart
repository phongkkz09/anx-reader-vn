import 'package:anx_reader/config/shared_preference_provider.dart';

/// Model for a web novel source
class WebSource {
  final String id;
  final String name;
  final String baseUrl;
  final String iconUrl;
  final String contentSelector;
  final String titleSelector;
  final String chapterListSelector;
  final String nextChapterSelector;
  final String prevChapterSelector;
  final bool isCustom;
  final bool isEnabled;

  WebSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.iconUrl = '',
    this.contentSelector = '',
    this.titleSelector = '',
    this.chapterListSelector = '',
    this.nextChapterSelector = '',
    this.prevChapterSelector = '',
    this.isCustom = false,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'iconUrl': iconUrl,
        'contentSelector': contentSelector,
        'titleSelector': titleSelector,
        'chapterListSelector': chapterListSelector,
        'nextChapterSelector': nextChapterSelector,
        'prevChapterSelector': prevChapterSelector,
        'isCustom': isCustom,
        'isEnabled': isEnabled,
      };

  factory WebSource.fromJson(Map<String, dynamic> json) {
    return WebSource(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      iconUrl: json['iconUrl'] as String? ?? '',
      contentSelector: json['contentSelector'] as String? ?? '',
      titleSelector: json['titleSelector'] as String? ?? '',
      chapterListSelector: json['chapterListSelector'] as String? ?? '',
      nextChapterSelector: json['nextChapterSelector'] as String? ?? '',
      prevChapterSelector: json['prevChapterSelector'] as String? ?? '',
      isCustom: json['isCustom'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  WebSource copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? iconUrl,
    String? contentSelector,
    String? titleSelector,
    String? chapterListSelector,
    String? nextChapterSelector,
    String? prevChapterSelector,
    bool? isCustom,
    bool? isEnabled,
  }) {
    return WebSource(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      contentSelector: contentSelector ?? this.contentSelector,
      titleSelector: titleSelector ?? this.titleSelector,
      chapterListSelector: chapterListSelector ?? this.chapterListSelector,
      nextChapterSelector: nextChapterSelector ?? this.nextChapterSelector,
      prevChapterSelector: prevChapterSelector ?? this.prevChapterSelector,
      isCustom: isCustom ?? this.isCustom,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// Predefined Vietnamese novel sources
class PredefinedSources {
  static final List<WebSource> vietnamese = [
    WebSource(
      id: 'truyenfull',
      name: 'Truyện Full',
      baseUrl: 'https://truyenfull.vn',
      contentSelector: '.chapter-content, #chapter-content, .content',
      titleSelector: '.chapter-title, h1.title, .title',
      chapterListSelector: '.list-chapter a, .chapter-list a',
      nextChapterSelector: '.next-chapter, a[rel="next"]',
      prevChapterSelector: '.prev-chapter, a[rel="prev"]',
    ),
    WebSource(
      id: 'webtruyen',
      name: 'Web Truyện',
      baseUrl: 'https://webtruyen.com',
      contentSelector: '.content, #content, .chapter-content',
      titleSelector: '.title, h1, .chapter-title',
      chapterListSelector: '.list-chapter a, .chapters a',
      nextChapterSelector: 'a.next, .next',
      prevChapterSelector: 'a.prev, .prev',
    ),
    WebSource(
      id: 'metruyencv',
      name: 'Mê Truyện Chữ',
      baseUrl: 'https://metruyencv.com',
      contentSelector: '#chapter-content, .content',
      titleSelector: '.chapter-title, h1',
      chapterListSelector: '.chapter-list a',
      nextChapterSelector: 'a.next-chapter',
      prevChapterSelector: 'a.prev-chapter',
    ),
    WebSource(
      id: 'truyenchu',
      name: 'Truyện Chữ',
      baseUrl: 'https://truyenchu.vn',
      contentSelector: '.chapter-content, #content',
      titleSelector: '.chapter-title, h1',
      chapterListSelector: '.list-chapter a',
      nextChapterSelector: 'a[rel="next"]',
      prevChapterSelector: 'a[rel="prev"]',
    ),
    WebSource(
      id: 'yytruyen',
      name: 'YY Truyện',
      baseUrl: 'https://yytruyen.com',
      contentSelector: '.content, #content',
      titleSelector: '.title, h1',
      chapterListSelector: '.chapters a',
      nextChapterSelector: 'a.next',
      prevChapterSelector: 'a.prev',
    ),
    WebSource(
      id: 'docln',
      name: 'Đọc Light Novel',
      baseUrl: 'https://docln.net',
      contentSelector: '.content, #content',
      titleSelector: '.title, h1',
      chapterListSelector: '.chapter-list a',
      nextChapterSelector: 'a.next',
      prevChapterSelector: 'a.prev',
    ),
  ];

  static final List<WebSource> international = [
    WebSource(
      id: 'novelfull',
      name: 'NovelFull',
      baseUrl: 'https://novelfull.com',
      contentSelector: '.chapter-content, #chapter-content',
      titleSelector: '.chapter-title, h1',
      chapterListSelector: '.chapter-list a',
      nextChapterSelector: 'a[rel="next"]',
      prevChapterSelector: 'a[rel="prev"]',
    ),
    WebSource(
      id: 'wuxiaworld',
      name: 'WuxiaWorld',
      baseUrl: 'https://wuxiaworld.com',
      contentSelector: '.chapter-content, .content',
      titleSelector: '.chapter-title, h1',
      chapterListSelector: '.chapters a',
      nextChapterSelector: 'a.next-chapter',
      prevChapterSelector: 'a.prev-chapter',
    ),
  ];

  static List<WebSource> get all => [...vietnamese, ...international];
}

/// Service to manage web sources
class WebSourceService {
  static final WebSourceService _instance = WebSourceService._internal();

  factory WebSourceService() => _instance;

  WebSourceService._internal();

  static const String _customSourcesKey = 'web_reader_custom_sources';
  static const String _disabledSourcesKey = 'web_reader_disabled_sources';

  /// Get all available sources (predefined + custom)
  List<WebSource> getAllSources() {
    final custom = _getCustomSources();
    final disabled = _getDisabledSourceIds();

    return [
      ...PredefinedSources.all.map((s) => s.copyWith(
            isEnabled: !disabled.contains(s.id),
          )),
      ...custom,
    ];
  }

  /// Get enabled sources only
  List<WebSource> getEnabledSources() {
    return getAllSources().where((s) => s.isEnabled).toList();
  }

  /// Find source by ID
  WebSource? getSourceById(String id) {
    return getAllSources().firstWhere((s) => s.id == id, orElse: () => getAllSources().first);
  }

  /// Detect source from URL
  WebSource? detectSource(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();

    for (final source in getAllSources()) {
      final sourceHost = Uri.parse(source.baseUrl).host.toLowerCase();
      if (host.contains(sourceHost) || sourceHost.contains(host)) {
        return source;
      }
    }

    return null;
  }

  /// Enable/disable a source
  void toggleSource(String sourceId, bool enabled) {
    final disabled = _getDisabledSourceIds();
    if (enabled) {
      disabled.remove(sourceId);
    } else {
      disabled.add(sourceId);
    }
    Prefs().prefs.setStringList(_disabledSourcesKey, disabled);
  }

  /// Add custom source
  void addCustomSource(WebSource source) {
    final custom = _getCustomSources();
    custom.removeWhere((s) => s.id == source.id);
    custom.add(source);
    _saveCustomSources(custom);
  }

  /// Remove custom source
  void removeCustomSource(String sourceId) {
    final custom = _getCustomSources();
    custom.removeWhere((s) => s.id == sourceId);
    _saveCustomSources(custom);
  }

  /// Update custom source
  void updateCustomSource(WebSource source) {
    addCustomSource(source);
  }

  List<WebSource> _getCustomSources() {
    final raw = Prefs().prefs.getString(_customSourcesKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = _parseSourceList(raw);
      return decoded.map((e) => WebSource.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  void _saveCustomSources(List<WebSource> sources) {
    final jsonList = sources.map((e) => e.toJson()).toList();
    Prefs().prefs.setString(_customSourcesKey, jsonList.toString());
  }

  List<String> _getDisabledSourceIds() {
    return Prefs().prefs.getStringList(_disabledSourcesKey) ?? [];
  }

  List<Map<String, dynamic>> _parseSourceList(String raw) {
    final result = <Map<String, dynamic>>[];
    final entries = RegExp(r'\{([^}]*)\}').allMatches(raw);

    for (final match in entries) {
      final content = match.group(1) ?? '';
      final map = <String, dynamic>{};
      for (final pair in RegExp(r"(\w+):\s*([^,]+)").allMatches(content)) {
        final key = pair.group(1) ?? '';
        var value = pair.group(2)?.trim() ?? '';
        if (value.startsWith("'") || value.startsWith('"')) {
          value = value.substring(1, value.length - 1);
        }
        map[key] = value;
      }
      if (map.isNotEmpty) result.add(map);
    }

    return result;
  }
}
