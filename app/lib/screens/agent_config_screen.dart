/// Agent 配置页（独立页面，从设置页进入）
///
/// OpenAI 兼容格式。配置项：baseURL / API Key / 模型（可拉取列表）/
/// 请求超时 / HTTP 代理。保存后缓存本地（agent_config 表），下次打开自动回填。
library;

import 'package:flutter/material.dart';

import '../models/agent_config.dart';
import '../services/agent/agent_api_client.dart';
import '../services/agent/agent_config_service.dart';

class AgentConfigScreen extends StatefulWidget {
  const AgentConfigScreen({super.key});

  @override
  State<AgentConfigScreen> createState() => _AgentConfigScreenState();
}

class _AgentConfigScreenState extends State<AgentConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  final _baseUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _timeoutCtrl = TextEditingController();
  final _proxyCtrl = TextEditingController();

  bool _obscureApiKey = true;
  bool _saving = false;
  bool _testing = false;
  bool _fetchingModels = false;
  TestResult? _testResult;
  DateTime? _savedAt;

  AgentConfig get _currentConfig => AgentConfig(
        baseUrl: _baseUrlCtrl.text.trim(),
        apiKey: _apiKeyCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        timeoutSec: int.tryParse(_timeoutCtrl.text.trim()) ?? 60,
        proxy: _proxyCtrl.text.trim().isEmpty ? null : _proxyCtrl.text.trim(),
      );

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final config = await AgentConfigService.instance.load();
    if (!mounted) return;
    setState(() {
      _baseUrlCtrl.text = config.baseUrl;
      _apiKeyCtrl.text = config.apiKey;
      _modelCtrl.text = config.model;
      _timeoutCtrl.text = '${config.timeoutSec}';
      _proxyCtrl.text = config.proxy ?? '';
      _savedAt = config.updatedAt;
    });
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _timeoutCtrl.dispose();
    _proxyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AgentConfigService.instance.save(_currentConfig);
      if (!mounted) return;
      setState(() => _savedAt = DateTime.now());
      _toast('✅ 配置已保存，下次打开自动使用');
    } catch (e) {
      _toast('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    // 测试前先保存，保证「测试通过 = 已落盘的配置可用」
    await AgentConfigService.instance.save(_currentConfig);
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final result = await AgentApiClient(_currentConfig).testConnection();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = result;
      _savedAt = DateTime.now();
    });
  }

  Future<void> _fetchModels() async {
    final config = _currentConfig;
    if (config.baseUrl.isEmpty || config.apiKey.isEmpty) {
      _toast('请先填写 baseURL 和 API Key');
      return;
    }
    setState(() => _fetchingModels = true);
    try {
      final models = await AgentApiClient(config).fetchModels();
      if (!mounted) return;
      if (models.isEmpty) {
        _toast('该服务未返回任何模型，请手动填写模型名');
      } else {
        await _showModelPicker(models);
      }
    } catch (e) {
      _toast('拉取失败：$e\n（部分服务不支持 /models 接口，可手动填写）');
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
  }

  Future<void> _showModelPicker(List<String> models) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: models.length,
          itemBuilder: (context, i) {
            final id = models[i];
            final isCurrent = id == _modelCtrl.text.trim();
            return ListTile(
              title: Text(id, style: const TextStyle(fontSize: 14)),
              trailing: isCurrent
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () => Navigator.pop(context, id),
            );
          },
        ),
      ),
    );
    if (picked != null) {
      setState(() => _modelCtrl.text = picked);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent 配置')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'OpenAI 兼容格式。配置保存后缓存本地，各板块 AI 功能将使用此配置。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _baseUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: '如 https://api.deepseek.com/v1（完整地址，原样使用不补全）',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '必填' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _apiKeyCtrl,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'API Key（sk-key）',
                hintText: 'sk-...',
                prefixIcon: const Icon(Icons.key),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureApiKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '必填' : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _modelCtrl,
                    decoration: const InputDecoration(
                      labelText: '模型（model）',
                      hintText: '如 deepseek-chat',
                      prefixIcon: Icon(Icons.smart_toy_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '必填' : null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _fetchingModels ? null : _fetchModels,
                    icon: _fetchingModels
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: const Text('拉取列表'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _timeoutCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '请求超时（秒）',
                hintText: '默认 60',
                prefixIcon: Icon(Icons.timer_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 5 || n > 600) return '5-600 之间的整数';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _proxyCtrl,
              decoration: const InputDecoration(
                labelText: 'HTTP 代理（可选）',
                hintText: '如 127.0.0.1:7890，留空直连',
                prefixIcon: Icon(Icons.vpn_lock_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: const Text('保存'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('测试连接'),
                  ),
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 16),
              _testResultCard(_testResult!),
            ],
            if (_savedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: Text(
                    '上次保存：${_savedAt!.toLocal().toString().substring(0, 19)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _testResultCard(TestResult result) {
    final ok = result.ok;
    final warn = result.ok && result.modelExists == false;
    final color = ok
        ? (warn ? Colors.orange : Colors.green)
        : Theme.of(context).colorScheme.error;
    final icon = ok
        ? (warn ? Icons.warning_amber_rounded : Icons.check_circle)
        : Icons.error_outline;
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(result.message,
                  style: TextStyle(color: color, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
