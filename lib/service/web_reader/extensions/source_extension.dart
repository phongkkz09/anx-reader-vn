import 'dart:convert';
import 'package:anx_reader/config/shared_preference_provider.dart';

/// Source Extension — defines a content extraction source
/// Can be predefined (built-in) or user-added (custom)
class SourceExtension {
  final String id;
  final String name;
  final String version;
  final String description;
  final String author;
  final String baseUrl;
  final String iconUrl;
  
  // CSS selectors for content extraction
  final String contentSelector;
  final String titleSelector;
  final String chapterListSelector;
  final String nextChapterSelector;
  final String prevChapterSelector;
  
  // Advanced: URL patterns for matching
  final List<String> urlPatterns;  // e.g. ["truyenfull.vn/*", "*.truyenfull.vn/*"]
  final List<String> excludePatterns;  // e.g. ["*/truyen-tranh/*"]
  
  // Metadata
  final bool isBuiltIn;
  final bool isEnabled;
  final DateTime? lastUpdated;
  final String? homepage;
  final String? sourceCodeUrl;  // For community extensions
  
  const SourceExtension({
    required this.id,
    required this.name,
    this.version = '1.0.0',
    this.description = '',
    this.author = '',
    required this.baseUrl,
    this.iconUrl = '',
    this.contentSelector = '',
    this.titleSelector = '',
    this.chapterListSelector = '',
    this.nextChapterSelector = '',
    this.prevChapterSelector = '',
    this.urlPatterns = const [],
    this.excludePatterns = const [],
    this.isBuiltIn = false,
    this.isEnabled = true,
    this.lastUpdated,
    this.homepage,
    this.sourceCodeUrl,
  });
  
  /// Check if a URL matches this source's patterns
  bool matchesUrl(String url) {
    if (urlPatterns.isEmpty) {
      // Fallback: check if URL contains base URL host
      try {
        final uri = Uri.parse(url);
        final baseUri = Uri.parse(baseUrl);
        return uri.host.contains(baseUri.host) || baseUri.host.contains(uri.host);
      } catch (_) {
        return false;
      }
    }
    
    for (final pattern in urlPatterns) {
      if (_matchesPattern(url, pattern)) return true;
    }
    return false;
  }
  
  bool _matchesPattern(String url, String pattern) {
    // Convert glob pattern to regex
    final regexPattern = pattern
        .replaceAll('.', '\\.')
        .replaceAll('*', '.*')
        .replaceAll('/', '\\/');
    final regex = RegExp('^$regexPattern$');
    return regex.hasMatch(url);
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'author': author,
    'baseUrl': baseUrl,
    'iconUrl': iconUrl,
    'contentSelector': contentSelector,
    'titleSelector': titleSelector,
    'chapterListSelector': chapterListSelector,
    'nextChapterSelector': nextChapterSelector,
    'prevChapterSelector': prevChapterSelector,
    'urlPatterns': urlPatterns,
    'excludePatterns': excludePatterns,
    'isBuiltIn': isBuiltIn,
    'isEnabled': isEnabled,
    'lastUpdated': lastUpdated?.toIso8601String(),
    'homepage': homepage,
    'sourceCodeUrl': sourceCodeUrl,
  };
  
  factory SourceExtension.fromJson(Map<String, dynamic> json) {
    return SourceExtension(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      description: json['description'] as String? ?? '',
      author: json['author'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      iconUrl: json['iconUrl'] as String? ?? '',
      contentSelector: json['contentSelector'] as String? ?? '',
      titleSelector: json['titleSelector'] as String? ?? '',
      chapterListSelector: json['chapterListSelector'] as String? ?? '',
      nextChapterSelector: json['nextChapterSelector'] as String? ?? '',
      prevChapterSelector: json['prevChapterSelector'] as String? ?? '',
      urlPatterns: List<String>.from(json['urlPatterns'] ?? []),
      excludePatterns: List<String>.from(json['excludePatterns'] ?? []),
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated']) 
          : null,
      homepage: json['homepage'] as String?,
      sourceCodeUrl: json['sourceCodeUrl'] as String?,
    );
  }
  
  SourceExtension copyWith({
    String? name,
    String? version,
    String? description,
    String? baseUrl,
    String? iconUrl,
    String? contentSelector,
    String? titleSelector,
    String? chapterListSelector,
    String? nextChapterSelector,
    String? prevChapterSelector,
    List<String>? urlPatterns,
    bool? isEnabled,
  }) {
    return SourceExtension(
      id: id,
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      author: author,
      baseUrl: baseUrl ?? this.baseUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      contentSelector: contentSelector ?? this.contentSelector,
      titleSelector: titleSelector ?? this.titleSelector,
      chapterListSelector: chapterListSelector ?? this.chapterListSelector,
      nextChapterSelector: nextChapterSelector ?? this.nextChapterSelector,
      prevChapterSelector: prevChapterSelector ?? this.prevChapterSelector,
      urlPatterns: urlPatterns ?? this.urlPatterns,
      excludePatterns: excludePatterns,
      isBuiltIn: isBuiltIn,
      isEnabled: isEnabled ?? this.isEnabled,
      lastUpdated: lastUpdated,
      homepage: homepage,
      sourceCodeUrl: sourceCodeUrl,
    );
  }
}
