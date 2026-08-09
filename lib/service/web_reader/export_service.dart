import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:anx_reader/service/web_reader/web_content_extractor.dart';
import 'package:anx_reader/service/web_reader/web_novel_library.dart';

/// Export result
class ExportResult {
  final String filePath;
  final String format; // epub, txt
  final int chapterCount;
  final int totalChars;
  final double sizeKB;

  const ExportResult({
    required this.filePath,
    required this.format,
    required this.chapterCount,
    required this.totalChars,
    required this.sizeKB,
  });
}

/// Progress callback
typedef ExportProgressCallback = void Function(int done, int total, String message);

/// Export Service
/// Exports web novel content to EPUB/TXT formats
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// Export novel chapters to EPUB
  /// [novelTitle]: Novel title
  /// [chapters]: List of (title, url, content) tuples
  Future<ExportResult> exportEpub({
    required String novelTitle,
    required String author,
    required List<Map<String, String>> chapters, // [{title, url, content}]
    ExportProgressCallback? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = _sanitizeFileName('$novelTitle.epub');
    final filePath = '${dir.path}/$fileName';

    final archive = Archive();

    // EPUB structure
    _addEpubContainer(archive);
    _addEpubMimetype(archive);
    _addEpubContentOpf(archive, novelTitle, author, chapters.length);
    _addEpubNavXhtml(archive, novelTitle, chapters);
    _addEpubCss(archive);

    // Add chapters as XHTML
    for (int i = 0; i < chapters.length; i++) {
      if (onProgress != null) {
        onProgress(i, chapters.length, 'Đang thêm chương ${i + 1}/${chapters.length}...');
      }
      final chapter = chapters[i];
      final chapterXhtml = _buildChapterXhtml(
        chapter['title'] ?? 'Chương ${i + 1}',
        chapter['content'] ?? '',
        i,
      );
      archive.addFile(ArchiveFile(
        'OEBPS/chapter_${i + 1}.xhtml',
        chapterXhtml.length,
        utf8.encode(chapterXhtml),
      ));
    }

    // Write ZIP
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw Exception('Không thể nén EPUB');
    }
    final file = File(filePath);
    await file.writeAsBytes(encoded);

    final totalChars = chapters.fold<int>(
      0,
      (sum, c) => sum + (c['content']?.length ?? 0),
    );

    return ExportResult(
      filePath: filePath,
      format: 'epub',
      chapterCount: chapters.length,
      totalChars: totalChars,
      sizeKB: encoded.length / 1024,
    );
  }

  /// Export novel to plain TXT
  Future<ExportResult> exportTxt({
    required String novelTitle,
    required List<Map<String, String>> chapters,
    ExportProgressCallback? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = _sanitizeFileName('$novelTitle.txt');
    final filePath = '${dir.path}/$fileName';

    final buffer = StringBuffer();
    buffer.writeln('=== $novelTitle ===');
    buffer.writeln('Xuất bởi Anx Reader VN');
    buffer.writeln('---');
    buffer.writeln();

    for (int i = 0; i < chapters.length; i++) {
      if (onProgress != null) {
        onProgress(i, chapters.length, 'Đang ghi chương ${i + 1}/${chapters.length}...');
      }
      final chapter = chapters[i];
      buffer.writeln();
      buffer.writeln('>>> ${chapter['title'] ?? 'Chương ${i + 1}'} <<<');
      buffer.writeln();
      buffer.writeln(_stripHtml(chapter['content'] ?? ''));
      buffer.writeln();
    }

    final content = buffer.toString();
    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);

    return ExportResult(
      filePath: filePath,
      format: 'txt',
      chapterCount: chapters.length,
      totalChars: content.length,
      sizeKB: content.length / 1024,
    );
  }

  /// Build chapter list from WebNovelItem
  /// Returns list of {title, url, content} — content must be filled by caller
  List<Map<String, String>> buildChaptersFromItem(
    String title,
    String url,
    int totalChapters,
  ) {
    return List.generate(
      totalChapters,
      (i) => {
        'title': title,
        'url': url,
        'content': '',
      },
    );
  }

  // ============ EPUB helpers ============

  void _addEpubMimetype(Archive archive) {
    final mimetype = 'application/epub+zip';
    archive.addFile(ArchiveFile('mimetype', mimetype.length, utf8.encode(mimetype)));
  }

  void _addEpubContainer(Archive archive) {
    const container = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
    archive.addFile(ArchiveFile('META-INF/container.xml', container.length, utf8.encode(container)));
  }

  void _addEpubContentOpf(Archive archive, String title, String author, int chapterCount) {
    final opf = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="bookid">urn:uuid:${_uuidV4()}</dc:identifier>
    <dc:title>${_escapeXml(title)}</dc:title>
    <dc:creator>${_escapeXml(author.isEmpty ? 'Unknown' : author)}</dc:creator>
    <dc:language>vi</dc:language>
    <meta property="dcterms:modified">${DateTime.now().toUtc().toIso8601String()}</meta>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="css" href="style.css" media-type="text/css"/>
    ${List.generate(chapterCount, (i) => '<item id="ch${i + 1}" href="chapter_${i + 1}.xhtml" media-type="application/xhtml+xml"/>').join('\n    ')}
  </manifest>
  <spine>
    ${List.generate(chapterCount, (i) => '<itemref idref="ch${i + 1}"/>').join('\n    ')}
  </spine>
</package>''';
    archive.addFile(ArchiveFile('OEBPS/content.opf', opf.length, utf8.encode(opf)));
  }

  void _addEpubNavXhtml(Archive archive, String title, List<Map<String, String>> chapters) {
    final navItems = chapters.asMap().entries.map((entry) {
      final i = entry.key;
      final chapter = entry.value;
      return '<li><a href="chapter_${i + 1}.xhtml">${_escapeXml(chapter['title'] ?? 'Chương ${i + 1}')}</a></li>';
    }).join('\n      ');

    final nav = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head>
  <title>${_escapeXml(title)}</title>
</head>
<body>
  <nav epub:type="toc" id="toc">
    <h1>${_escapeXml(title)}</h1>
    <ol>
      $navItems
    </ol>
  </nav>
</body>
</html>''';
    archive.addFile(ArchiveFile('OEBPS/nav.xhtml', nav.length, utf8.encode(nav)));
  }

  void _addEpubCss(Archive archive) {
    const css = '''body { font-family: serif; line-height: 1.6; margin: 1em; }
h1 { font-size: 1.5em; text-align: center; margin: 1em 0; }
p { margin: 0.5em 0; text-indent: 1.5em; }
.novel-title { text-align: center; font-size: 2em; margin: 2em 0; }
.chapter-title { text-align: center; font-size: 1.3em; margin: 1.5em 0; }''';
    archive.addFile(ArchiveFile('OEBPS/style.css', css.length, utf8.encode(css)));
  }

  String _buildChapterXhtml(String title, String content, int index) {
    // Convert plain text to paragraphs
    final paragraphs = _stripHtml(content)
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => '<p>${_escapeXml(p.trim())}</p>')
        .join('\n    ');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <link rel="stylesheet" type="text/css" href="style.css"/>
  <title>${_escapeXml(title)}</title>
</head>
<body>
  <h1 class="chapter-title">${_escapeXml(title)}</h1>
  $paragraphs
</body>
</html>''';
  }

  // ============ Utils ============

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _stripHtml(String html) {
    // Remove HTML tags
    var text = html.replaceAll(RegExp(r'<[^>]*>'), '');
    // Decode common entities
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return text;
  }

  String _uuidV4() {
    final rnd = DateTime.now().microsecondsSinceEpoch;
    return '$rnd-4a2b-8c1d-${rnd % 0xFFFF}';
  }
}
