import 'package:flutter/material.dart';
import 'package:anx_reader/service/web_reader/ai_provider_manager.dart';
import 'package:anx_reader/service/web_reader/tts_backend_manager.dart';

/// Provider Config Dialog
/// Shows AI providers and TTS backends with enable/disable/config
class ProviderConfigDialog extends StatefulWidget {
  const ProviderConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ProviderConfigDialog(),
    );
  }

  @override
  State<ProviderConfigDialog> createState() => _ProviderConfigDialogState();
}

class _ProviderConfigDialogState extends State<ProviderConfigDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AiProviderManager _aiManager = AiProviderManager();
  final TtsBackendManager _ttsManager = TtsBackendManager();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _aiManager.load();
    _ttsManager.load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
              child: Row(
                children: [
                  const Icon(Icons.settings_suggest),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Cấu hình AI & TTS',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'AI Providers (${_aiManager.enabled.length})'),
                Tab(text: 'TTS Backends (${_ttsManager.enabled.length})'),
              ],
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAiProvidersList(),
                  _buildTtsBackendsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiProvidersList() {
    final providers = _aiManager.all;
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: providers.length,
      itemBuilder: (context, index) {
        final p = providers[index];
        final isActive = _aiManager.activeId == p.id;
        final isConfigured = _aiManager.isProviderConfigured(p.id);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isActive
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              child: Icon(
                isActive ? Icons.check_circle : Icons.circle_outlined,
                color: isActive ? Colors.green : Colors.grey,
              ),
            ),
            title: Row(
              children: [
                Expanded(child: Text(p.name)),
                if (p.isBuiltIn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Built-in', style: TextStyle(fontSize: 10)),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.model.isNotEmpty ? p.model : p.type),
                if (!isConfigured && p.type != 'system')
                  Text(
                    'Chưa cấu hình API key',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 11),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(p.isEnabled ? Icons.visibility_off : Icons.visibility),
                      const SizedBox(width: 8),
                      Text(p.isEnabled ? 'Tắt' : 'Bật'),
                    ],
                  ),
                ),
                if (p.type != 'system')
                  PopupMenuItem(
                    value: 'config',
                    child: const Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Cấu hình'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'set_active',
                  child: Row(
                    children: [
                      Icon(isActive ? Icons.star : Icons.star_border),
                      const SizedBox(width: 8),
                      Text(isActive ? 'Đang active' : 'Đặt làm mặc định'),
                    ],
                  ),
                ),
              ],
              onSelected: (action) {
                switch (action) {
                  case 'toggle':
                    _aiManager.toggleProvider(p.id);
                    setState(() {});
                    break;
                  case 'config':
                    _showAiConfigDialog(p);
                    break;
                  case 'set_active':
                    _aiManager.setActive(p.id);
                    setState(() {});
                    break;
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTtsBackendsList() {
    final backends = _ttsManager.all;
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: backends.length,
      itemBuilder: (context, index) {
        final b = backends[index];
        final isActive = _ttsManager.activeId == b.id;
        final isConfigured = _ttsManager.isBackendConfigured(b.id);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isActive
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              child: Icon(
                isActive ? Icons.volume_up : Icons.volume_down,
                color: isActive ? Colors.green : Colors.grey,
              ),
            ),
            title: Row(
              children: [
                Expanded(child: Text(b.name)),
                if (b.isBuiltIn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Built-in', style: TextStyle(fontSize: 10)),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.voice.isNotEmpty ? b.voice : b.type),
                if (!isConfigured && b.type != 'system')
                  Text(
                    'Chưa cấu hình API key',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 11),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(b.isEnabled ? Icons.visibility_off : Icons.visibility),
                      const SizedBox(width: 8),
                      Text(b.isEnabled ? 'Tắt' : 'Bật'),
                    ],
                  ),
                ),
                if (b.type != 'system')
                  PopupMenuItem(
                    value: 'config',
                    child: const Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Cấu hình'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'set_active',
                  child: Row(
                    children: [
                      Icon(isActive ? Icons.star : Icons.star_border),
                      const SizedBox(width: 8),
                      Text(isActive ? 'Đang active' : 'Đặt làm mặc định'),
                    ],
                  ),
                ),
              ],
              onSelected: (action) {
                switch (action) {
                  case 'toggle':
                    _ttsManager.toggleBackend(b.id);
                    setState(() {});
                    break;
                  case 'config':
                    _showTtsConfigDialog(b);
                    break;
                  case 'set_active':
                    _ttsManager.setActive(b.id);
                    setState(() {});
                    break;
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _showAiConfigDialog(AiProviderConfig provider) {
    final apiKeyController = TextEditingController(text: provider.apiKey);
    final modelController = TextEditingController(text: provider.model);
    final apiBaseController = TextEditingController(text: provider.apiBase);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cấu hình ${provider.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiBaseController,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  border: OutlineInputBorder(),
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
              final updated = provider.copyWith(
                apiKey: apiKeyController.text.trim(),
                model: modelController.text.trim(),
                apiBase: apiBaseController.text.trim(),
              );
              _aiManager.updateProvider(updated);
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã lưu cấu hình ${provider.name}')),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showTtsConfigDialog(TtsBackendConfig backend) {
    final apiKeyController = TextEditingController(text: backend.apiKey);
    final voiceController = TextEditingController(text: backend.voice);
    final apiBaseController = TextEditingController(text: backend.apiBase);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cấu hình ${backend.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: voiceController,
                decoration: const InputDecoration(
                  labelText: 'Voice Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiBaseController,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  border: OutlineInputBorder(),
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
              final updated = backend.copyWith(
                apiKey: apiKeyController.text.trim(),
                voice: voiceController.text.trim(),
                apiBase: apiBaseController.text.trim(),
              );
              _ttsManager.updateBackend(updated);
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã lưu cấu hình ${backend.name}')),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
