/// XP 积分规则 — 见 f3.md §二
library;

/// 每日 XP 上限（防刷分）
const int kDailyXpCap = 150;

/// 等级阈值（累计 XP），12 级
const List<int> kXpThresholds = [
  0, 50, 150, 300, 500, 800, 1200, 1700, 2300, 3000, 4000, 5500,
];

/// XP 来源及数值 — f3.md §2.1
///
/// 调用方使用 [XpService.awardXP] 时引用此处的枚举与数值，
/// 禁止在业务代码里硬编码 XP 数值。
enum XpSource {
  quizCorrect('quiz_correct', 2), // 答题正确
  quizWrongMarked('quiz_wrong_marked', 1), // 答错但已标记（鼓励"错了也学"）
  sessionComplete('session_complete', 10), // 板块 session 完成
  reviewClear('review_clear', 15), // 复习队列清空
  combo('combo', 5), // 连续正确 5 题
  dailyQuest('daily_quest', 0), // 每日任务（单项 5/10，见 f3 §7.2）
  dailyQuestAll('daily_quest_all', 20), // 每日任务全部完成
  streakBonus('streak_bonus', 30), // streak 每满 7 天
  grammarDiscovery('grammar_discovery', 3), // 首次接触新语法点
  reviewCorrect('review_correct', 2), // 复习 rating≥3
  reviewHard('review_hard', 1); // 复习 rating=2

  const XpSource(this.logTag, this.defaultAmount);

  /// 写入 xp_log.source 的字符串
  final String logTag;

  /// 默认 XP 数值（dailyQuest 等动态数额由调用方覆盖）
  final int defaultAmount;
}
