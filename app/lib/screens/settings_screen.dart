/// 设置页 — 分板块结构
///
/// 对应 V1 页面 5「设置页」。板块划分：
/// ① Agent 配置（AI 服务）—— 入口条目，点击进入独立的 AgentConfigScreen
/// ② 学习偏好 —— 每日新词目标（user_profile.daily_goal_vocab）
/// ③ 发音偏好 —— 口音 / 自动播放（user_profile.tts_accent / tts_autoplay）
/// ④ 数据管理 —— 导出 / 备份（待开发）
/// ⑤ 关于
///
/// 简单项（②③）改动即存；Agent 配置在独立页面用显式保存。
library;

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../data/storage_service.dart';
import '../models/agent_config.dart';
import '../services/agent/agent_config_service.dart';
import '../services/tts/tts_service.dart';
import '../services/xp_service.dart';
import 'agent_config_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Agent 配置摘要（详情在独立页面维护）──
  AgentConfig? _agentConfig;

  // ── 学习偏好 ──
  int _dailyGoal = 10;

  // ── 发音偏好 ──
  TtsAccent _accent = TtsAccent.us;
  bool _autoplay = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final config = await AgentConfigService.instance.load();
    final profile = await XpService.instance.getProfile(kLocalUserId);
    if (!mounted) return;
    setState(() {
      _agentConfig = config;
      _dailyGoal = (profile?['daily_goal_vocab'] as int?) ?? 10;
      final accentDb = (profile?['tts_accent'] as String?) ?? 'us';
      _accent = switch (accentDb) {
        'uk' => TtsAccent.uk,
        'au' => TtsAccent.au,
        _ => TtsAccent.us,
      };
      _autoplay = (profile?['tts_autoplay'] as int? ?? 1) == 1;
    });
  }

  /// 简单项即时落库（user_profile，字段名为固定字面量，无注入风险）
  Future<void> _updateProfile(String field, Object value) async {
    await StorageService.instance.execute(
      'UPDATE user_profile SET $field = ? WHERE user_id = ?',
      [value, kLocalUserId],
    );
  }

  // ═══════════════════════ 简单项动作 ═══════════════════════

  Future<void> _setDailyGoal(int value) async {
    setState(() => _dailyGoal = value);
    await _updateProfile('daily_goal_vocab', value);
  }

  Future<void> _setAccent(TtsAccent value) async {
    setState(() => _accent = value);
    await _updateProfile('tts_accent', value.name);
    TTSService.instance.invalidateAccentCache(); // 下次朗读立即生效
  }

  Future<void> _setAutoplay(bool value) async {
    setState(() => _autoplay = value);
    await _updateProfile('tts_autoplay', value ? 1 : 0);
  }

  Future<void> _openAgentConfig() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgentConfigScreen()),
    );
    // 返回后刷新摘要（可能已保存新配置）
    await _loadSaved();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ═══════════════════════ UI ═══════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _agentEntry(),
          const SizedBox(height: 12),
          _learningSection(),
          const SizedBox(height: 12),
          _speechSection(),
          const SizedBox(height: 12),
          _dataSection(),
          const SizedBox(height: 12),
          _aboutSection(),
        ],
      ),
    );
  }

  // ── ① Agent 配置（入口条目）──

  Widget _agentEntry() {
    final config = _agentConfig;
    final configured = config?.isConfigured ?? false;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.smart_toy_outlined),
        title: const Text('Agent 配置',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(
          configured
              ? '${config!.model} · ${_briefUrl(config.baseUrl)}'
              : '未配置 · 各板块 AI 功能需要此配置',
          style: TextStyle(
            fontSize: 12,
            color: configured ? Colors.grey : Colors.orange,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openAgentConfig,
      ),
    );
  }

  String _briefUrl(String url) {
    // 去协议前缀，过长截断，摘要更清爽
    var u = url.replaceFirst(RegExp(r'^https?://'), '');
    return u.length > 28 ? '${u.substring(0, 28)}…' : u;
  }

  // ── ② 学习偏好 ──

  Widget _learningSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.school_outlined),
                SizedBox(width: 12),
                Text('学习偏好',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('每日新词目标')),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed:
                      _dailyGoal > 5 ? () => _setDailyGoal(_dailyGoal - 5) : null,
                ),
                Text('$_dailyGoal',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _dailyGoal < 100
                      ? () => _setDailyGoal(_dailyGoal + 5)
                      : null,
                ),
              ],
            ),
            const Text('词汇板块每次练习的新词数量上限（改动即时生效）',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ── ③ 发音偏好 ──

  Widget _speechSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.record_voice_over_outlined),
                SizedBox(width: 12),
                Text('发音偏好',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('口音')),
                SegmentedButton<TtsAccent>(
                  segments: const [
                    ButtonSegment(value: TtsAccent.us, label: Text('美音')),
                    ButtonSegment(value: TtsAccent.uk, label: Text('英音')),
                    ButtonSegment(value: TtsAccent.au, label: Text('澳音')),
                  ],
                  selected: {_accent},
                  onSelectionChanged: (s) => _setAccent(s.first),
                  showSelectedIcon: false,
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自动播放发音'),
              subtitle: const Text('练习中遇到单词/例句时自动朗读',
                  style: TextStyle(fontSize: 12)),
              value: _autoplay,
              onChanged: _setAutoplay,
            ),
          ],
        ),
      ),
    );
  }

  // ── ④ 数据管理 ──

  Widget _dataSection() {
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.folder_zip_outlined),
            title: Text('数据管理',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('导出学习数据'),
            subtitle: const Text('SRS 卡片 / XP 流水 / 错题记录',
                style: TextStyle(fontSize: 12)),
            trailing: const Chip(
                label: Text('待开发', style: TextStyle(fontSize: 10))),
            onTap: () => _toast('数据导出 · 待开发（V1 里程碑内）'),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('数据库位置'),
            subtitle: const Text('本地 SQLite，随配置缓存',
                style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _toast('备份：直接拷贝 linguaflow.db 文件'),
          ),
        ],
      ),
    );
  }

  // ── ⑤ 关于 ──

  Widget _aboutSection() {
    return Card(
      child: const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('关于 LinguaFlow'),
        subtitle: Text('V1 MVP · Flutter + SQLite · 离线优先',
            style: TextStyle(fontSize: 12)),
      ),
    );
  }
}
