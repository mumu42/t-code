/// 全局常量 — 见 LinguaFlow.md / modules-connect.md
///
/// V1 为纯本地应用（无注册登录），全库固定单用户 'local'。
library;

/// 本地单用户 ID（V1 无账号系统，见 f1.md §七.9）
const String kLocalUserId = 'local';

/// CEFR 等级顺序（定级模块难度阶梯，见 f1.md §三.1）
const List<String> kCefrOrder = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

/// 复习 Session 每轮上限（见 f4.md §十.8：20 due + 5 new = 25 张）
const int kReviewSessionDueLimit = 20;
const int kReviewSessionNewLimit = 5;

// ── 种子/用户内容 ID 前缀约定 ──
// 复习页按 item_id 前缀决定去哪张表解析内容（srs_cards 表结构零改动）。
// 前缀跨版本必须稳定：SRS 卡片弱引用种子 id，id 变更会导致孤儿卡。

/// seed_words 内置词库前缀，如 'w_refactor'
const String kSeedWordIdPrefix = 'w_';

/// vocab_cards 用户/AI 词卡前缀，如 'uv_1732512_abc'
const String kUserVocabIdPrefix = 'uv_';

/// seed_sentences 精听/硬句/跟读句前缀，如 's_standup_001'
const String kSeedSentenceIdPrefix = 's_';

/// seed_reading_passages 阅读篇章前缀，如 'p_flutter_state'
const String kSeedPassageIdPrefix = 'p_';

/// seed_speaking_scenarios 口语场景前缀，如 'sc_code_review'
const String kSeedScenarioIdPrefix = 'sc_';

/// seed_collocations 写作搭配前缀，如 'col_pick_up'
const String kSeedCollocationIdPrefix = 'col_';

/// seed_writing_prompts 写作题目前缀，如 'wp_fix_bug'
const String kSeedWritingPromptIdPrefix = 'wp_';

/// 生成一条用户词卡 id
String generateUserVocabId() {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final rand = DateTime.now().microsecondsSinceEpoch % 0x10000;
  return '$kUserVocabIdPrefix$ts}_${rand.toRadixString(36)}';
}
