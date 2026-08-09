import 'package:flutter/material.dart';
import 'package:anx_reader/service/web_reader/download_manager.dart';

/// Download Manager UI - shows download queue, progress, controls
class DownloadManagerSheet extends StatefulWidget {
  const DownloadManagerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const DownloadManagerSheet(),
    );
  }

  @override
  State<DownloadManagerSheet> createState() => _DownloadManagerSheetState();
}

class _DownloadManagerSheetState extends State<DownloadManagerSheet> {
  final DownloadManager _manager = DownloadManager();
  
  @override
  Widget build(BuildContext context) {
    final tasks = _manager.tasks;
    final downloading = tasks.where((t) => t.status == DownloadStatus.downloading).toList();
    final pending = tasks.where((t) => t.status == DownloadStatus.pending).toList();
    final completed = tasks.where((t) => t.status == DownloadStatus.completed).toList();
    final failed = tasks.where((t) => t.status == DownloadStatus.failed).toList();
    
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            _buildHeader(tasks.length),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  if (downloading.isNotEmpty) ...[
                    _buildSection('Đang tải (${downloading.length})', downloading),
                    const SizedBox(height: 16),
                  ],
                  if (pending.isNotEmpty) ...[
                    _buildSection('Chờ tải (${pending.length})', pending),
                    const SizedBox(height: 16),
                  ],
                  if (failed.isNotEmpty) ...[
                    _buildSection('Lỗi (${failed.length})', failed),
                    const SizedBox(height: 16),
                  ],
                  if (completed.isNotEmpty) ...[
                    _buildSection('Hoàn thành (${completed.length})', completed),
                  ],
                  if (tasks.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Chưa có tải xuống nào',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildHeader(int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.download, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tải xuống ($total)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (total > 0)
            TextButton(
              onPressed: () {
                _manager.clearCompleted();
                setState(() {});
              },
              child: const Text('Xóa hoàn thành'),
            ),
        ],
      ),
    );
  }
  
  Widget _buildSection(String title, List<DownloadTask> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...tasks.map((task) => _buildTaskItem(task)),
      ],
    );
  }
  
  Widget _buildTaskItem(DownloadTask task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                _buildStatusChip(task.status),
              ],
            ),
            if (task.bookTitle != null) ...[
              const SizedBox(height: 4),
              Text(
                task.bookTitle!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (task.status == DownloadStatus.downloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: task.progress),
              const SizedBox(height: 4),
              Text(
                '${(task.progress * 100).toStringAsFixed(1)}% • ${_formatBytes(task.downloadedBytes)} / ${task.totalBytes != null ? _formatBytes(task.totalBytes!) : "..."}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (task.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                task.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            _buildTaskActions(task),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusChip(DownloadStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case DownloadStatus.pending:
        color = Colors.grey;
        label = 'Chờ';
        break;
      case DownloadStatus.downloading:
        color = Colors.blue;
        label = 'Tải';
        break;
      case DownloadStatus.paused:
        color = Colors.orange;
        label = 'Tạm dừng';
        break;
      case DownloadStatus.completed:
        color = Colors.green;
        label = 'Xong';
        break;
      case DownloadStatus.failed:
        color = Colors.red;
        label = 'Lỗi';
        break;
      case DownloadStatus.cancelled:
        color = Colors.grey;
        label = 'Hủy';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
  
  Widget _buildTaskActions(DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return Row(
          children: [
            TextButton.icon(
              onPressed: () {
                _manager.pause(task.id);
                setState(() {});
              },
              icon: const Icon(Icons.pause),
              label: const Text('Tạm dừng'),
            ),
            TextButton.icon(
              onPressed: () {
                _manager.cancel(task.id);
                setState(() {});
              },
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: const Text('Hủy', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      case DownloadStatus.paused:
        return Row(
          children: [
            TextButton.icon(
              onPressed: () {
                _manager.resume(task.id);
                setState(() {});
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Tiếp tục'),
            ),
            TextButton.icon(
              onPressed: () {
                _manager.cancel(task.id);
                setState(() {});
              },
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: const Text('Hủy', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      case DownloadStatus.failed:
        return Row(
          children: [
            TextButton.icon(
              onPressed: () {
                _manager.retry(task.id);
                setState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
            TextButton.icon(
              onPressed: () {
                _manager.remove(task.id);
                setState(() {});
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      case DownloadStatus.completed:
        return TextButton.icon(
          onPressed: () {
            _manager.remove(task.id);
            setState(() {});
          },
          icon: const Icon(Icons.delete),
          label: const Text('Xóa'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
  
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
