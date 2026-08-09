import 'package:flutter/material.dart';
import 'package:anx_reader/service/web_reader/web_novel_library.dart';
import 'package:anx_reader/page/web_reader/web_reader_page.dart';

/// Web Novel Library Page
/// Shows tracked web novels with progress, update status, favorite toggle
class WebNovelLibraryPage extends StatefulWidget {
  const WebNovelLibraryPage({super.key});

  @override
  State<WebNovelLibraryPage> createState() => _WebNovelLibraryPageState();
}

class _WebNovelLibraryPageState extends State<WebNovelLibraryPage> {
  final WebNovelLibrary _library = WebNovelLibrary();
  SortOption _sortOption = SortOption.lastRead;
  bool _ascending = false;
  String _filterSource = 'all';
  
  @override
  void initState() {
    super.initState();
    _library.load();
  }
  
  List<WebNovelItem> get _filteredItems {
    var items = _library.sort(_sortOption, ascending: _ascending);
    
    if (_filterSource != 'all') {
      items = items.where((i) => i.sourceName == _filterSource).toList();
    }
    
    return items;
  }
  
  Set<String> get _availableSources {
    return _library.items.map((i) => i.sourceName).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Truyện theo dõi'),
        centerTitle: true,
        actions: [
          // Stats badge
          if (_library.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Chip(
                  label: Text('${_library.items.length}'),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
            ),
          // Sort menu
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (option) {
              setState(() {
                if (_sortOption == option) {
                  _ascending = !_ascending;
                } else {
                  _sortOption = option;
                  _ascending = false;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: SortOption.title,
                child: Row(
                  children: [
                    const Text('Tên'),
                    if (_sortOption == SortOption.title)
                      Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortOption.lastRead,
                child: Row(
                  children: [
                    const Text('Đọc gần đây'),
                    if (_sortOption == SortOption.lastRead)
                      Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortOption.progress,
                child: Row(
                  children: [
                    const Text('Tiến độ'),
                    if (_sortOption == SortOption.progress)
                      Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Source filter chips
          if (_availableSources.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  FilterChip(
                    label: const Text('Tất cả'),
                    selected: _filterSource == 'all',
                    onSelected: (_) => setState(() => _filterSource = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ..._availableSources.map((source) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(source),
                      selected: _filterSource == source,
                      onSelected: (_) => setState(() => _filterSource = source),
                    ),
                  )),
                ],
              ),
            ),
          // Novel list
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Chưa có truyện nào được theo dõi',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Mở Web Reader → dán link → thêm vào thư viện',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildNovelCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNovelCard(WebNovelItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: InkWell(
        onTap: () {
          // Open Web Reader with this novel
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WebReaderPage(),
              settings: RouteSettings(arguments: item.url),
            ),
          ).then((_) => setState(() => _library.load()));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Progress indicator
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: item.progress,
                      strokeWidth: 3,
                      backgroundColor: Colors.grey.shade300,
                    ),
                    Text(
                      '${(item.progress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.isFavorite)
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                      ],
                    ),
                    if (item.author != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.author!,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.language, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          item.sourceName,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.book, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${item.lastChapterIndex + 1}/${item.totalChapters > 0 ? item.totalChapters : "?"}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'favorite',
                    child: Row(
                      children: [
                        Icon(item.isFavorite ? Icons.star_border : Icons.star),
                        const SizedBox(width: 8),
                        Text(item.isFavorite ? 'Bỏ thích' : 'Yêu thích'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'update',
                    child: Row(
                      children: [
                        Icon(item.autoUpdate ? Icons.sync_disabled : Icons.sync),
                        const SizedBox(width: 8),
                        Text(item.autoUpdate ? 'Tắt tự động' : 'Bật tự động'),
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
                onSelected: (value) {
                  setState(() {
                    switch (value) {
                      case 'favorite':
                        _library.toggleFavorite(item.id);
                        break;
                      case 'update':
                        _library.toggleAutoUpdate(item.id);
                        break;
                      case 'delete':
                        _showDeleteConfirm(item);
                        break;
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showDeleteConfirm(WebNovelItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa khỏi thư viện?'),
        content: Text('Xóa "${item.title}" khỏi danh sách theo dõi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              _library.removeNovel(item.id);
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã xóa "${item.title}"')),
              );
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
