import 'package:flutter/material.dart';
import 'package:anx_reader/service/web_reader/export_service.dart';
import 'package:anx_reader/service/web_reader/web_content_extractor.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

/// Export Dialog
/// Allows user to choose format (EPUB/TXT) and export novel
class ExportDialog extends StatefulWidget {
  final String novelTitle;
  final String novelAuthor;
  final List<WebChapter> chapters;
  final Future<String> Function(String url) fetchChapterContent;

  const ExportDialog({
    super.key,
    required this.novelTitle,
    this.novelAuthor = 'Unknown',
    required this.chapters,
    required this.fetchChapterContent,
  });

  static Future<void> show({
    required BuildContext context,
    required String novelTitle,
    String novelAuthor = 'Unknown',
    required List<WebChapter> chapters,
    required Future<String> Function(String url) fetchChapterContent,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ExportDialog(
        novelTitle: novelTitle,
        novelAuthor: novelAuthor,
        chapters: chapters,
        fetchChapterContent: fetchChapterContent,
      ),
    );
  }

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  final ExportService _exportService = ExportService();
  String _selectedFormat = 'epub';
  bool _isExporting = false;
  int _exportedCount = 0;
  String _statusMessage = '';
  ExportResult? _result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.file_download),
          const SizedBox(width: 12),
          Expanded(child: Text('Xuất truyện: ${widget.novelTitle}')),
        ],
      ),
      content: _isExporting
          ? _buildProgressUI()
          : _result != null
              ? _buildResultUI()
              : _buildSelectionUI(),
      actions: _isExporting
          ? []
          : _result != null
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  FilledButton.icon(
                    onPressed: _startExport,
                    icon: const Icon(Icons.download),
                    label: const Text('Xuất file'),
                  ),
                ],
    );
  }

  Widget _buildSelectionUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Số chương: ${widget.chapters.length}'),
        const SizedBox(height: 16),
        const Text('Định dạng:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        RadioListTile<String>(
          title: const Text('EPUB (.epub)'),
          subtitle: const Text('E-book chuẩn, đọc trên các app sách'),
          value: 'epub',
          groupValue: _selectedFormat,
          onChanged: (v) => setState(() => _selectedFormat = v!),
        ),
        RadioListTile<String>(
          title: const Text('TXT (.txt)'),
          subtitle: const Text('Văn bản đơn giản, dễ chia sẻ'),
          value: 'txt',
          groupValue: _selectedFormat,
          onChanged: (v) => setState(() => _selectedFormat = v!),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sẽ tải nội dung ${widget.chapters.length} chương từ web',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressUI() {
    final progress = widget.chapters.isEmpty
        ? 1.0
        : _exportedCount / widget.chapters.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 16),
        Text(
          'Đang xuất...',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '$_exportedCount / ${widget.chapters.length} chương',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_statusMessage.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _statusMessage,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildResultUI() {
    final r = _result!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 8),
            const Text('Xuất thành công!'),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Định dạng', r.format.toUpperCase()),
        _buildInfoRow('Số chương', '${r.chapterCount}'),
        _buildInfoRow('Ký tự', '${r.totalChars}'),
        _buildInfoRow('Kích thước', '${r.sizeKB.toStringAsFixed(1)} KB'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: () => _openFile(r.filePath),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Mở'),
            ),
            TextButton.icon(
              onPressed: () => _shareFile(r.filePath),
              icon: const Icon(Icons.share),
              label: const Text('Chia sẻ'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _startExport() async {
    setState(() {
      _isExporting = true;
      _exportedCount = 0;
      _statusMessage = 'Đang chuẩn bị...';
    });

    try {
      // Fetch all chapters content
      final chapters = <Map<String, String>>[];
      for (int i = 0; i < widget.chapters.length; i++) {
        final chapter = widget.chapters[i];
        setState(() {
          _statusMessage = 'Đang tải chương ${i + 1}...';
        });

        String content = '';
        try {
          content = await widget.fetchChapterContent(chapter.url);
        } catch (e) {
          content = '[Lỗi tải nội dung: $e]';
        }

        chapters.add({
          'title': chapter.title,
          'url': chapter.url,
          'content': content,
        });

        setState(() {
          _exportedCount = i + 1;
        });
      }

      // Export to selected format
      setState(() {
        _statusMessage = 'Đang tạo file ${_selectedFormat.toUpperCase()}...';
      });

      final result = _selectedFormat == 'epub'
          ? await _exportService.exportEpub(
              novelTitle: widget.novelTitle,
              author: widget.novelAuthor,
              chapters: chapters,
              onProgress: (done, total, msg) {
                setState(() => _statusMessage = msg);
              },
            )
          : await _exportService.exportTxt(
              novelTitle: widget.novelTitle,
              chapters: chapters,
              onProgress: (done, total, msg) {
                setState(() => _statusMessage = msg);
              },
            );

      setState(() {
        _isExporting = false;
        _result = result;
      });
    } catch (e) {
      setState(() {
        _isExporting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xuất file: $e')),
        );
      }
    }
  }

  Future<void> _openFile(String path) async {
    await OpenFile.open(path);
  }

  Future<void> _shareFile(String path) async {
    await Share.shareXFiles(
      [XFile(path)],
      subject: widget.novelTitle,
      text: 'Truyện: ${widget.novelTitle}',
    );
  }
}
