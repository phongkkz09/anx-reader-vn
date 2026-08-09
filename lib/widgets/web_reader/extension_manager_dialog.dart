import 'package:flutter/material.dart';
import 'package:anx_reader/service/web_reader/extensions/extension_registry.dart';
import 'package:anx_reader/service/web_reader/extensions/source_extension.dart';

/// Extension Manager Dialog
/// Shows all available extensions (built-in + custom)
/// Allows enable/disable, add/remove custom, import/export
class ExtensionManagerDialog extends StatefulWidget {
  const ExtensionManagerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ExtensionManagerDialog(),
    );
  }

  @override
  State<ExtensionManagerDialog> createState() => _ExtensionManagerDialogState();
}

class _ExtensionManagerDialogState extends State<ExtensionManagerDialog>
    with SingleTickerProviderStateMixin {
  final ExtensionRegistry _registry = ExtensionRegistry();
  late TabController _tabController;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _registry.load();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  List<SourceExtension> get _filteredExtensions {
    if (_searchQuery.isEmpty) return _registry.all;
    return _registry.search(_searchQuery);
  }
  
  List<SourceExtension> get _builtInExtensions => 
      _filteredExtensions.where((e) => e.isBuiltIn).toList();
  
  List<SourceExtension> get _customExtensions => 
      _filteredExtensions.where((e) => !e.isBuiltIn).toList();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.extension),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Quản lý nguồn',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '${_registry.enabledCount} active',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm nguồn...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Sẵn có (${_builtInExtensions.length})'),
                Tab(text: 'Tùy chỉnh (${_customExtensions.length})'),
              ],
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExtensionList(_builtInExtensions, isCustom: false),
                  _buildExtensionList(_customExtensions, isCustom: true),
                ],
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _importExtension,
                    icon: const Icon(Icons.download),
                    label: const Text('Nhập JSON'),
                  ),
                  TextButton.icon(
                    onPressed: _exportExtensions,
                    icon: const Icon(Icons.upload),
                    label: const Text('Xuất JSON'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _addCustomExtension,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm mới'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExtensionList(List<SourceExtension> extensions, {required bool isCustom}) {
    if (extensions.isEmpty) {
      return Center(
        child: Text(
          isCustom ? 'Chưa có nguồn tùy chỉnh' : 'Không tìm thấy nguồn',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: extensions.length,
      itemBuilder: (context, index) {
        final ext = extensions[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: ext.isEnabled
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              child: Icon(
                ext.isEnabled ? Icons.check_circle : Icons.cancel,
                color: ext.isEnabled ? Colors.green : Colors.grey,
              ),
            ),
            title: Row(
              children: [
                Expanded(child: Text(ext.name)),
                if (!ext.isBuiltIn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Custom', style: TextStyle(fontSize: 10, color: Colors.blue)),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ext.description.isNotEmpty)
                  Text(ext.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${ext.baseUrl.isNotEmpty ? ext.baseUrl : "Any URL"} • v${ext.version}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(ext.isEnabled ? Icons.visibility_off : Icons.visibility),
                      const SizedBox(width: 8),
                      Text(ext.isEnabled ? 'Tắt' : 'Bật'),
                    ],
                  ),
                ),
                if (isCustom) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'edit',
                    child: const Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Chỉnh sửa'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('Xóa', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ],
              onSelected: (action) => _handleAction(action, ext),
            ),
          ),
        );
      },
    );
  }
  
  void _handleAction(String action, SourceExtension ext) {
    switch (action) {
      case 'toggle':
        _registry.toggleExtension(ext.id);
        setState(() {});
        break;
      case 'edit':
        _editCustomExtension(ext);
        break;
      case 'delete':
        _confirmDelete(ext);
        break;
    }
  }
  
  void _addCustomExtension() {
    _showExtensionForm(null);
  }
  
  void _editCustomExtension(SourceExtension ext) {
    _showExtensionForm(ext);
  }
  
  void _showExtensionForm(SourceExtension? existing) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final baseUrlController = TextEditingController(text: existing?.baseUrl ?? '');
    final contentController = TextEditingController(text: existing?.contentSelector ?? '');
    final titleController = TextEditingController(text: existing?.titleSelector ?? '');
    final chapterController = TextEditingController(text: existing?.chapterListSelector ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final patternsController = TextEditingController(
      text: existing?.urlPatterns.join(', ') ?? '',
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing != null ? 'Sửa nguồn' : 'Thêm nguồn mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên nguồn *'),
              ),
              TextField(
                controller: baseUrlController,
                decoration: const InputDecoration(labelText: 'URL gốc *'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'Content Selector (CSS)'),
              ),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title Selector (CSS)'),
              ),
              TextField(
                controller: chapterController,
                decoration: const InputDecoration(labelText: 'Chapter List Selector (CSS)'),
              ),
              TextField(
                controller: patternsController,
                decoration: const InputDecoration(
                  labelText: 'URL Patterns (phẩy phân cách)',
                  hintText: 'e.g. truyenfull.vn/*, *.truyenfull.vn/*',
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
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final baseUrl = baseUrlController.text.trim();
              if (name.isEmpty || baseUrl.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tên và URL gốc là bắt buộc')),
                );
                return;
              }
              
              final patterns = patternsController.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              
              final ext = SourceExtension(
                id: existing?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
                name: name,
                baseUrl: baseUrl,
                description: descController.text.trim(),
                contentSelector: contentController.text.trim(),
                titleSelector: titleController.text.trim(),
                chapterListSelector: chapterController.text.trim(),
                urlPatterns: patterns,
                isBuiltIn: false,
                isEnabled: true,
              );
              
              _registry.addExtension(ext);
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã lưu nguồn "$name"')),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
  
  void _confirmDelete(SourceExtension ext) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nguồn?'),
        content: Text('Xóa "${ext.name}"? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              _registry.removeExtension(ext.id);
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã xóa "${ext.name}"')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
  
  void _importExtension() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập Extension từ JSON'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Paste JSON array of extensions...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final count = _registry.importFromJson(controller.text);
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã nhập $count nguồn')),
              );
            },
            child: const Text('Nhập'),
          ),
        ],
      ),
    );
  }
  
  void _exportExtensions() {
    final json = _registry.exportToJson();
    final controller = TextEditingController(text: json);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xuất Extensions (JSON)'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          readOnly: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
