/// 首页 Dashboard — 见 LinguaFlow.md §四（V1 页面 1）
///
/// 展示：streak + 能力等级（XPBar）+ 每日任务 + 六大板块入口 + 复习角标。
/// 各板块页面为 V1 开发项，当前点击显示占位提示。
library;

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../constants/levels.dart';
import '../data/storage_service.dart';
import '../services/srs_service.dart';
import '../services/xp_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LinguaFlow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置（开发中）',
            onPressed: () => _todo(context, '设置页'),
          ),
        ],
      ),
      body: !StorageService.instance.isReady
          ? const _WebUnsupportedNotice()
          : FutureBuilder<_HomeData>(
              future: _HomeData.load(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('数据加载失败：${snapshot.error}'));
                }
                final data = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: () async {},
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StreakAndLevelCard(data: data),
                      const SizedBox(height: 12),
                      _DailyQuestsCard(data: data),
                      const SizedBox(height: 12),
                      _BoardGrid(dueCount: data.dueCount),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _todo(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what · 待开发（V1 里程碑内）')),
    );
  }
}

// ──────────────────────────────────────────────────────────
// 数据加载
// ──────────────────────────────────────────────────────────

class _HomeData {
  const _HomeData({
    required this.streakDays,
    required this.level,
    required this.totalXp,
    required this.nextXp,
    required this.xpProgress,
    required this.dueCount,
    required this.quests,
  });

  final int streakDays;
  final LevelDef level;
  final int totalXp;
  final int nextXp;
  final double xpProgress;
  final int dueCount;
  final _QuestStatus quests;

  static Future<_HomeData> load() async {
    final profile = await XpService.instance.getProfile(kLocalUserId);
    final totalXp = (profile?['total_xp'] as int?) ?? 0;
    final streakDays = (profile?['streak_days'] as int?) ?? 0;
    final idx = XpService.calculateLevelIndex(totalXp);
    final next = XpService.getXPForNextLevel(totalXp);
    final dueCount =
        await SrsService.instance.getDueCount(kLocalUserId);
    final quests = await _QuestStatus.load();

    return _HomeData(
      streakDays: streakDays,
      level: kLevels[idx],
      totalXp: totalXp,
      nextXp: next.next,
      xpProgress: next.progress,
      dueCount: dueCount,
      quests: quests,
    );
  }
}

class _QuestStatus {
  const _QuestStatus(
      this.quest1, this.quest2, this.quest3, this.allCompleted);

  final bool quest1; // 完成 1 个板块练习
  final bool quest2; // 清空复习队列
  final bool quest3; // 完成 2 个不同板块
  final bool allCompleted;

  static Future<_QuestStatus> load() async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final rows = await StorageService.instance.query(
      'SELECT quest_1_done, quest_2_done, quest_3_done, all_completed '
      'FROM daily_quests WHERE user_id = ? AND quest_date = ?',
      [kLocalUserId, today],
    );
    if (rows.isEmpty) {
      return const _QuestStatus(false, false, false, false);
    }
    final r = rows.first;
    bool flag(String k) => (r[k] as int? ?? 0) == 1;
    return _QuestStatus(
        flag('quest_1_done'), flag('quest_2_done'), flag('quest_3_done'),
        flag('all_completed'));
  }
}

// ──────────────────────────────────────────────────────────
// 组件
// ──────────────────────────────────────────────────────────

/// streak + 能力等级常驻展示（f3 §9.3）
class _StreakAndLevelCard extends StatelessWidget {
  const _StreakAndLevelCard({required this.data});

  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🔥 ${data.streakDays} 天',
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                Text('${data.level.visual} ${data.level.name} '
                    'L${data.level.index + 1}/12',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: data.xpProgress,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text('${data.totalXp} / ${data.nextXp} XP',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(data.level.description,
                style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// 每日任务卡（f3 §9.5）
class _DailyQuestsCard extends StatelessWidget {
  const _DailyQuestsCard({required this.data});

  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final q = data.quests;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📋 每日任务',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _questRow('完成 1 个板块练习', q.quest1),
            _questRow('清空复习队列', q.quest2),
            _questRow('完成 2 个不同板块', q.quest3),
            if (q.allCompleted)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('🎉 今日任务全部完成 +1 冻结卡'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _questRow(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(done ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

/// 六大板块入口（复习带角标）— LinguaFlow.md §三
class _BoardGrid extends StatelessWidget {
  const _BoardGrid({required this.dueCount});

  final int dueCount;

  static const _boards = [
    (Icons.style, '词汇', 'Vocabulary'),
    (Icons.headphones, '听力', 'Listening'),
    (Icons.menu_book, '阅读', 'Reading'),
    (Icons.mic, '口语', 'Speaking'),
    (Icons.edit_note, '写作', 'Writing'),
    (Icons.repeat, '复习', 'Review'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: _boards.length,
      itemBuilder: (context, i) {
        final (icon, cn, en) = _boards[i];
        final isReview = en == 'Review';
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$cn板块 · 待开发（V1 里程碑内）')),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 32),
                      const SizedBox(height: 8),
                      Text(cn, style: const TextStyle(fontSize: 16)),
                      Text(en,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                if (isReview && dueCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Badge(
                      label: Text('$dueCount'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Web 端占位（sqflite 不支持 Web，见 README「平台支持」）
class _WebUnsupportedNotice extends StatelessWidget {
  const _WebUnsupportedNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.computer, size: 48),
            const SizedBox(height: 16),
            Text(
              'Web 端暂不支持本地数据库',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'LinguaFlow 为离线优先应用，V1 以 Android / iOS 为主。\n'
              'Web 端数据库支持将在 V2 接入 sqflite_common_ffi_web。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
