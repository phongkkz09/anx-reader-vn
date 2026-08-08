import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

/// Model for extracted web content
class WebContent {
  final String title;
  final String content;
  final String? nextChapterUrl;
  final List<String> chapters; // List of chapter titles
  final int currentChapterIndex;

  WebContent({
    required this.title,
    required this.content,
    this.nextChapterUrl,
    this.chapters = const [],
    this.currentChapterIndex = 0,
  });
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

      // Extract next chapter URL
      final nextUrl = _extractNextChapterUrl(document, url);

      // Extract chapter list
      final chapters = _extractChapters(document);

      return WebContent(
        title: title,
        content: content,
        nextChapterUrl: nextUrl,
        chapters: chapters,
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
    // Try common content containers
    final contentSelectors = [
      'article',
      '.article-content',
      '.post-content',
      '.chapter-content',
      '.content',
      '#content',
      'main',
    ];

    html_dom.Element? contentElement;
    for (final selector in contentSelectors) {
      contentElement = document.querySelector(selector);
      if (contentElement != null) break;
    }

    // Fallback to body if no container found
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
      'script',
      'style',
      'nav',
      'footer',
      '.advertisement',
      '.ad',
      '.ads',
      '.sidebar',
      '.comments',
      '.comment-form',
      '#comments',
      '.social-share',
      '.share-buttons',
      'ins', // Google ads
      '.adsbox',
      '[data-ad-client]',
      '[data-adsbygoogle]',
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
      'a.next',
      '.next-chapter',
      'a[rel="next"]',
      '.pagination a.next',
      'a:contains("Next")',
      'a:contains("next")',
      'a:contains("Tiếp theo")',
    ];

    for (final selector in nextSelectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final href = element.attributes['href'];
        if (href != null) {
          return _resolveUrl(href, baseUrl);
        }
      }
    }

    return null;
  }

  /// Extract chapter list for navigation
  List<String> _extractChapters(html_dom.Document document) {
    final chapterSelectors = [
      '.chapter-list li a',
      '.chapters li a',
      'nav.toc a',
      '.toc a',
    ];

    for (final selector in chapterSelectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        return elements
            .map((e) => e.text.trim())
            .where((text) => text.isNotEmpty)
            .toList();
      }
    }

    return [];
  }

  /// Resolve relative URLs
  String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http')) {
      return url;
    }

    final base = Uri.parse(baseUrl);
    if (url.startsWith('/')) {
      return '${base.scheme}://${base.host}$url';
    }

    return '${base.scheme}://${base.host}${base.path}/$url';
  }
}
