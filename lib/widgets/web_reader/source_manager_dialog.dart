import 'package:flutter/material.dart';
import 'package:anx_reader/service/web_reader/web_source.dart';

/// Dialog to manage and select web sources
class SourceManagerDialog extends StatefulWidget {
  final WebSourceService service;
  final Function(WebSource)? onSourceSelected;

  const SourceManagerDialog({
    super.key,
    required this.service,
    this.onSourceSelected,
  });

  @override
  State<SourceManagerDialog> createState() => _SourceManagerDialogState();

  /// Show the dialog
  static Future<void> show(
    BuildContext context, {
    required WebSourceService service,
    Function(WebSource)? onSourceSelected,
  }) {
    return showDialog(
      context: context,
      builder: (context) => SourceManagerDialog(
        service: service,
        onSourceSelected: onSourceSelected,
      ),
    );
  }
}

class _SourceManagerDialogState extends State<SourceManagerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<WebSource> _sources;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSources();
  }

  void _loadSources() {
    _sources = widget.service.getAllSources();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<WebSource> _filterSources(List<WebSource> sources) {
    if (_searchQuery.isEmpty) return sources;
    final query = _searchQuery.toLowerCase();
    return sources.where((s) {
      return s.name.toLowerCase().contains(query) ||
          s.baseUrl.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vietnamese = _filterSources(PredefinedSources.vietnamese);
    final international = _filterSources(PredefinedSources.international);
    final custom =
        _filterSources(_sources.where((s) => s.isCustom).toList());

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Nguồn truyện',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _showAddCustomSourceDialog(),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Thêm nguồn mới',
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Search
            TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm nguồn...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 12),
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Tiếng Việt'),
                Tab(text: 'Quốc tế'),
              ],
            ),
            // Source Lists
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSourceList(vietnamese),
                  _buildSourceList(international),
                ],
              ),
            ),
            // Custom sources section
            if (custom.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Text(
                      'Nguồn tùy chỉnh',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '${custom.length} nguồn',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 120,
                child: _buildSourceList(custom, isCustom: true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceList(List<WebSource> sources, {bool isCustom = false}) {
    if (sources.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty
              ? 'Chưa có nguồn nào'
              : 'Không tìm thấy nguồn',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              source.name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(source.name),
          subtitle: Text(
            source.baseUrl,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCustom)
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditCustomSourceDialog(source),
                ),
              Switch(
                value: source.isEnabled,
                onChanged: (value) {
                  widget.service.toggleSource(source.id, value);
                  setState(() {
                    _loadSources();
                  });
                },
              ),
            ],
          ),
          onTap: () {
            if (widget.onSourceSelected != null) {
              widget.onSourceSelected!(source);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }

  void _showAddCustomSourceDialog() {
    _showCustomSourceDialog(null);
  }

  void _showEditCustomSourceDialog(WebSource source) {
    _showCustomSourceDialog(source);
  }

  void _showCustomSourceDialog(WebSource? existing) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final urlController = TextEditingController(text: existing?.baseUrl ?? '');
    final contentController =
        TextEditingController(text: existing?.contentSelector ?? '');
    final titleController =
        TextEditingController(text: existing?.titleSelector ?? '');
    final chapterController =
        TextEditingController(text: existing?.chapterListSelector ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Thêm nguồn mới' : 'Sửa nguồn'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên nguồn *',
                  hintText: 'VD: Truyện Hay',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'URL chính *',
                  hintText: 'https://truyenhay.com',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'CSS selector nội dung',
                  hintText: '.content, #chapter-content',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'CSS selector tiêu đề',
                  hintText: '.title, h1',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: chapterController,
                decoration: const InputDecoration(
                  labelText: 'CSS selector danh sách chương',
                  hintText: '.chapter-list a',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final url = urlController.text.trim();

              if (name.isEmpty || url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng điền tên và URL')),
                );
                return;
              }

              final source = WebSource(
                id: existing?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
                name: name,
                baseUrl: url,
                contentSelector: contentController.text.trim(),
                titleSelector: titleController.text.trim(),
                chapterListSelector: chapterController.text.trim(),
                isCustom: true,
              );

              widget.service.addCustomSource(source);
              Navigator.pop(context);
              setState(() {
                _loadSources();
              });
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
