import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

/// Model for a single chapter
class WebChapter {
  final String title;
  final String url;
  final int index;

  WebChapter({
    required this.title,
    required this.url,
    required this.index,
  });
}

/// Model for extracted web content
class WebContent {
  final String title;
  final String content;
  final String url;
  final String? nextChapterUrl;
  final String? prevChapterUrl;
  final List<WebChapter> chapters; // Full chapter list with URLs
  final int currentChapterIndex;

  WebContent({
    required this.title,
    required this.content,
    required this.url,
    this.nextChapterUrl,
    this.prevChapterUrl,
    this.chapters = const [],
    this.currentChapterIndex = -1,
  });

  /// Check if has next chapter
  bool get hasNextChapter => nextChapterUrl != null;

  /// Check if has prev chapter
  bool get hasPrevChapter => prevChapterUrl != null;

  /// Get current chapter
  WebChapter? get currentChapter {
    if (currentChapterIndex >= 0 && currentChapterIndex < chapters.length) {
      return chapters[currentChapterIndex];
    }
    return null;
  }
}

/// Service to fetch and extract content from web sources
class WebContentExtractor {
  static final WebContentExtractor _instance =
      WebContentExtractor._internal();

  factory WebContentExtractor() {
    return _instance;
  }

  WebContentExtractor._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ),
  );

  /// Extract content from a web URL
  Future<WebContent> extractContent(String url) async {
    try {
      final response = await _dio.get(url);
      final document = html_parser.parse(response.data);

      // Extract title
      final title = _extractTitle(document);

      // Extract main content
      final content = _extractMainContent(document);

      // Extract navigation URLs
      final nextUrl = _extractNextChapterUrl(document, url);
      final prevUrl = _extractPrevChapterUrl(document, url);

      // Extract chapter list with URLs
      final chapters = _extractChapters(document, url);
      final currentIndex = _findCurrentChapterIndex(chapters, url);

      return WebContent(
        title: title,
        content: content,
        url: url,
        nextChapterUrl: nextUrl,
        prevChapterUrl: prevUrl,
        chapters: chapters,
        currentChapterIndex: currentIndex,
      );
    } catch (e) {
      throw Exception('Failed to extract content from $url: $e');
    }
  }

  /// Extract page title
  String _extractTitle(html_dom.Document document) {
    // Try common title selectors
    final selectors = [
      'h1',
      'h1.title',
      'h1.chapter-title',
      '.chapter-title',
      'title',
      '.post-title',
    ];

    for (final selector in selectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final text = element.text.trim();
        if (text.isNotEmpty) return text;
      }
    }

    return 'Untitled';
  }

  /// Extract main content and clean ads/clutter
  String _extractMainContent(html_dom.Document document) {
    // Site-specific selectors first (priority order)
    final siteSpecificSelectors = [
      '#chapter-content', // TruyenFull, WebTruyen
      '.chapter-content', // Most VN novel sites
      '.content-chapter', // MeTruyenChu
      '.reading-detail', // Some sites
      'div.txt', // TruyenFull variant
    ];
    
    // Generic content containers (fallback)
    final contentSelectors = [
      'article',
      '.article-content',
      '.post-content',
      'main',
      '[role="main"]',
      '.content',
      '#content',
      '.entry-content',
      '.text-content',
    ];

    // Try site-specific first
    html_dom.Element? contentElement;
    for (final selector in siteSpecificSelectors) {
      contentElement = document.querySelector(selector);
      if (contentElement != null && contentElement.text.trim().length > 50) break;
      contentElement = null;
    }
    
    // Fallback to generic selectors
    contentElement ??= (() {
      for (final selector in contentSelectors) {
        final el = document.querySelector(selector);
        if (el != null && el.text.trim().length > 50) return el;
      }
      return null;
    })();

    // Last resort: body
    contentElement ??= document.body;

    if (contentElement == null) return '';

    // Clone to avoid modifying original
    final clone = contentElement.clone(true) as html_dom.Element;

    // Remove unwanted elements
    _removeUnwantedElements(clone);

    // Extract text and clean it
    return _cleanText(clone.text);
  }

  /// Remove ads, scripts, styles, navigation, etc.
  void _removeUnwantedElements(html_dom.Element element) {
    final selectorsToRemove = [
      // Scripts & styles
      'script',
      'style',
      'noscript',
      // Navigation & layout
      'nav',
      'header',
      'footer',
      '.header',
      '.footer',
      '.navbar',
      '.navigation',
      '.breadcrumb',
      // Ads
      '.advertisement',
      '.ad',
      '.ads',
      '.ad-container',
      '.ad-wrapper',
      '.adbox',
      '.adsbox',
      '.adsbygoogle',
      '[data-ad-client]',
      '[data-adsbygoogle]',
      'ins',
      // Sidebar & widgets
      '.sidebar',
      '.widget',
      '.widget-area',
      '.side-bar',
      // Comments
      '.comments',
      '.comment-form',
      '#comments',
      '#comment',
      '.comment-area',
      // Social
      '.social-share',
      '.share-buttons',
      '.share',
      '.social',
      // Chapter nav (will be extracted separately)
      '.chapter-nav',
      '.chapter-navigation',
      '.nav-chapter',
      '.btn-chapter',
      // Popups & modals
      '.modal',
      '.popup',
      '.overlay',
      '.lightbox',
      // Hidden elements
      '[style*="display: none"]',
      '[style*="display:none"]',
      '.hidden',
      '.d-none',
      // Specific site ads
      '.google-auto-placed',
      '.dfp-tag',
      '#google_ads_iframe',
    ];

    for (final selector in selectorsToRemove) {
      element.querySelectorAll(selector).forEach((e) => e.remove());
    }
  }

  /// Clean extracted text
  String _cleanText(String text) {
    // Remove multiple spaces and newlines
    text = text.replaceAll(RegExp(r'\n\s*\n'), '\n');
    text = text.replaceAll(RegExp(r' +'), ' ');
    text = text.trim();

    return text;
  }

  /// Extract next chapter URL
  String? _extractNextChapterUrl(html_dom.Document document, String baseUrl) {
    final nextSelectors = [
      // Site-specific
      'a.btn-next', 'a.next-chapter', 'a[title="Next"]', 'a[title="Tiếp theo"]',
      '.chapter-nav a:last-child', '.nav-chapter a:last-child',
      // Generic
      'a.next', '.next-chapter', 'a[rel="next"]', '.pagination a.next',
      'a:contains("Next")', 'a:contains("next")', 'a:contains("Tiếp theo")',
      'a:contains("next chapter")',
    ];
    for (final selector in nextSelectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final href = element.attributes['href'];
        if (href != null && href.isNotEmpty) {
          return _resolveUrl(href, baseUrl);
        }
      }
    }
    return null;
  }

  /// Extract previous chapter URL
  String? _extractPrevChapterUrl(html_dom.Document document, String baseUrl) {
    final prevSelectors = [
      // Site-specific
      'a.btn-prev', 'a.prev-chapter', 'a[title="Prev"]', 'a[title="Trước"]',
      '.chapter-nav a:first-child', '.nav-chapter a:first-child',
      // Generic
      'a.prev', '.prev-chapter', 'a[rel="prev"]', '.pagination a.prev',
      'a:contains("Previous")', 'a:contains("prev")', 'a:contains("Trước")',
    ];
    for (final selector in prevSelectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final href = element.attributes['href'];
        if (href != null && href.isNotEmpty) {
          return _resolveUrl(href, baseUrl);
        }
      }
    }
    return null;
  }

  /// Extract chapter list with URLs
  List<WebChapter> _extractChapters(html_dom.Document document, String currentUrl) {
    final chapterSelectors = [
      // Site-specific
      '.chapter-list li a', '.list-chapter a', '#list-chapter a',
      '.chapters li a', '.chapter-items a', '.list-chap a',
      // Generic
      'nav.toc a', '.toc a', '.table-of-contents a',
      '.chapter-nav a', '[class*="chapter"] a', '[class*="toc"] a',
      'a[href*="chapter"]',
    ];
    for (final selector in chapterSelectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.length >= 2) {
        final chapters = <WebChapter>[];
        for (int i = 0; i < elements.length; i++) {
          final text = elements[i].text.trim();
          final href = elements[i].attributes['href'];
          if (text.isNotEmpty && href != null && href.isNotEmpty) {
            chapters.add(WebChapter(
              title: text,
              url: _resolveUrl(href, currentUrl),
              index: i,
            ));
          }
        }
        if (chapters.length >= 2) return chapters;
      }
    }
    return [];
  }

  /// Find current chapter index
  int _findCurrentChapterIndex(List<WebChapter> chapters, String currentUrl) {
    if (chapters.isEmpty) return -1;
    final normalizedCurrent = _normalizeUrl(currentUrl);
    for (int i = 0; i < chapters.length; i++) {
      if (_normalizeUrl(chapters[i].url) == normalizedCurrent) return i;
    }
    return -1;
  }

  /// Normalize URL for comparison
  String _normalizeUrl(String url) {
    return url.replaceAll(RegExp(r'\?.*$'), '').replaceAll(RegExp(r'#.*$'), '')
        .replaceAll(RegExp(r'/$'), '').toLowerCase();
  }

  /// Resolve relative URLs
  String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http')) return url;
    final base = Uri.parse(baseUrl);
    if (url.startsWith('/')) return '${base.scheme}://${base.host}$url';
    return '${base.scheme}://${base.host}${base.path}/$url';
  }
}
