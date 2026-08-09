import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

/// Byte order for UTF-16 decoding
enum _Endianness { little, big }

/// Custom exception for Web Reader errors
class WebReaderException implements Exception {
  final String message;
  final String? url;

  WebReaderException(this.message, {this.url});

  @override
  String toString() => message;
}

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
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      // Detect encoding from headers + meta tags, then decode properly
      final htmlText = _decodeHtml(
        response.data ?? <int>[],
        response.headers.value('content-type'),
      );

      final document = html_parser.parse(htmlText);

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
    } on DioException catch (e) {
      // Network/HTTP errors
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw WebReaderException(
            'Không thể kết nối đến website (timeout). Vui lòng thử lại sau.',
            url: url,
          );
        case DioExceptionType.connectionError:
          throw WebReaderException(
            'Không có kết nối mạng. Vui lòng kiểm tra internet.',
            url: url,
          );
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode ?? 0;
          if (code == 404) {
            throw WebReaderException(
              'Trang không tồn tại (404). Link có thể đã bị xóa.',
              url: url,
            );
          } else if (code == 403) {
            throw WebReaderException(
              'Truy cập bị từ chối (403). Website chặn yêu cầu.',
              url: url,
            );
          } else if (code >= 500) {
            throw WebReaderException(
              'Website đang gặp lỗi ($code). Vui lòng thử lại sau.',
              url: url,
            );
          }
          throw WebReaderException(
            'Lỗi tải trang ($code). Vui lòng thử lại.',
            url: url,
          );
        case DioExceptionType.cancel:
          throw WebReaderException('Yêu cầu đã bị hủy.', url: url);
        case DioExceptionType.badCertificate:
          throw WebReaderException(
            'Lỗi chứng chỉ SSL. Không thể kết nối an toàn.',
            url: url,
          );
        default:
          throw WebReaderException(
            'Lỗi mạng: ${e.message ?? "Không xác định"}',
            url: url,
          );
      }
    } on FormatException catch (e) {
      throw WebReaderException(
        'Định dạng URL không hợp lệ.',
        url: url,
      );
    } on WebReaderException {
      rethrow; // Already formatted
    } catch (e) {
      throw WebReaderException(
        'Lỗi không xác định: ${e.toString()}',
        url: url,
      );
    }
  }

  /// Decode raw HTML bytes using detected charset.
  ///
  /// Priority:
  /// 1. HTTP Content-Type header charset
  /// 2. `<meta charset>` / `<meta http-equiv="content-type">` in first 4KB
  /// 3. BOM detection (UTF-8 / UTF-16LE / UTF-16BE)
  /// 4. Fallback UTF-8
  ///
  /// Keeps UTF-8 untouched (fast path). Converts only when needed.
  String _decodeHtml(List<int> bytes, String? contentType) {
    if (bytes.isEmpty) return '';

    // 1. BOM detection (most reliable)
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowInvalid: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes.sublist(2), _Endianness.little);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes.sublist(2), _Endianness.big);
    }

    // 2. Charset from Content-Type header, e.g. "text/html; charset=windows-1258"
    final headerCharset = _extractCharset(contentType);
    if (headerCharset != null) {
      final decoded = _decodeWithCharset(bytes, headerCharset);
      if (decoded != null) return decoded;
    }

    // 3. Charset from <meta> tags (scan first 4KB as latin1 to find meta)
    final headSnippet = latin1.decode(
      bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes,
      allowInvalid: true,
    );
    final metaCharset = _extractMetaCharset(headSnippet);
    if (metaCharset != null) {
      final decoded = _decodeWithCharset(bytes, metaCharset);
      if (decoded != null) return decoded;
    }

    // 4. Fallback: try UTF-8, then latin1 (never throws)
    try {
      return utf8.decode(bytes, allowInvalid: true);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  /// Extract charset=... from Content-Type header value.
    String? _extractCharset(String? contentType) {
      if (contentType == null) return null;
      // Use normal string (not raw) to properly escape quotes in character class
      final match = RegExp('charset\\s*=\\s*["\']?([\\w-]+)', caseSensitive: false)
          .firstMatch(contentType);
      return match?.group(1)?.toLowerCase();
    }

  /// Extract charset from <meta> tags in head snippet.
    String? _extractMetaCharset(String headSnippet) {
      final metaCharset = RegExp(
        '<meta[^>]+charset\\s*=\\s*["\']?([\\w-]+)',
        caseSensitive: false,
      ).firstMatch(headSnippet);
      if (metaCharset != null) return metaCharset.group(1)!.toLowerCase();

      final httpEquiv = RegExp(
        '<meta[^>]+http-equiv\\s*=\\s*["\']?content-type["\']?[^>]*content\\s*=\\s*["\'][^"\']*charset\\s*=\\s*([\\w-]+)',
        caseSensitive: false,
      ).firstMatch(headSnippet);
      return httpEquiv?.group(1)?.toLowerCase();
    }

  /// Decode bytes using a charset name. Returns null for unsupported charsets.
  String? _decodeWithCharset(List<int> bytes, String charset) {
    switch (charset) {
      case 'utf-8':
      case 'utf8':
        return utf8.decode(bytes, allowInvalid: true);
      case 'utf-16':
      case 'utf-16le':
        return _decodeUtf16(bytes, _Endianness.little);
      case 'utf-16be':
        return _decodeUtf16(bytes, _Endianness.big);
      case 'latin1':
      case 'iso-8859-1':
      case 'iso-8859-2':
        return latin1.decode(bytes, allowInvalid: true);
      case 'windows-1258':
        // Vietnamese single-byte codepage (mostly ASCII-compatible + VN accents)
        return _decodeWindows1258(bytes);
      case 'windows-1252':
        return _decodeWindows1252(bytes);
      default:
        // Unknown charset (TCVN-12980, VISCII, etc.) — try UTF-8, keep original
        return null;
    }
  }

  /// Decode UTF-16 with explicit endianness.
  String _decodeUtf16(List<int> bytes, _Endianness endianness) {
    final units = <int>[];
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      units.add(endianness == _Endianness.little
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(units);
  }

  /// Decode Windows-1258 (Vietnamese, based on Windows-1252 with VN overrides).
  String _decodeWindows1258(List<int> bytes) {
    // Windows-1258 maps most bytes same as Windows-1252; Vietnamese
    // diacritics occupy 0x80-0x9F range. Use cp1252 table then override
    // the Vietnamese positions.
    const cp1252 = [
      0x20AC, 0xFFFD, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
      0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0xFFFD, 0x017D, 0xFFFD,
      0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
      0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0xFFFD, 0x017E, 0x0178,
    ];
    // Windows-1258 Vietnamese-specific replacements for 0x80-0x9F:
    // 0x80 À, 0x81 Á, 0x82 Â, 0x83 Ã, 0x84 È, 0x85 É, 0x86 Ê, 0x87 Ì,
    // 0x88 Í, 0x89 Ò, 0x8A Ó, 0x8B Ô, 0x8C Õ, 0x8D Ù, 0x8E Ú, 0x8F Ý,
    // 0x90 à, 0x91 á, 0x92 â, 0x93 ã, 0x94 è, 0x95 é, 0x96 ê, 0x97 ì,
    // 0x98 í, 0x99 ò, 0x9A ó, 0x9B ô, 0x9C õ, 0x9D ù, 0x9E ú, 0x9F ý
    const vnOverrides = [
      0x00C0, 0x00C1, 0x00C2, 0x00C3, 0x00C8, 0x00C9, 0x00CA, 0x00CC,
      0x00CD, 0x00D2, 0x00D3, 0x00D4, 0x00D5, 0x00D9, 0x00DA, 0x00DD,
      0x00E0, 0x00E1, 0x00E2, 0x00E3, 0x00E8, 0x00E9, 0x00EA, 0x00EC,
      0x00ED, 0x00F2, 0x00F3, 0x00F4, 0x00F5, 0x00F9, 0x00FA, 0x00FD,
    ];
    final sb = StringBuffer();
    for (final b in bytes) {
      if (b >= 0x80 && b <= 0x9F) {
        sb.writeCharCode(vnOverrides[b - 0x80]);
      } else if (b >= 0xA0) {
        sb.writeCharCode(cp1252[b - 0x80]);
      } else {
        sb.writeCharCode(b);
      }
    }
    return sb.toString();
  }

  /// Decode Windows-1252 (fallback for Western European sites).
  String _decodeWindows1252(List<int> bytes) {
    const cp1252 = [
      0x20AC, 0xFFFD, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
      0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0xFFFD, 0x017D, 0xFFFD,
      0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
      0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0xFFFD, 0x017E, 0x0178,
    ];
    final sb = StringBuffer();
    for (final b in bytes) {
      if (b >= 0x80) {
        sb.writeCharCode(cp1252[b - 0x80]);
      } else {
        sb.writeCharCode(b);
      }
    }
    return sb.toString();
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
