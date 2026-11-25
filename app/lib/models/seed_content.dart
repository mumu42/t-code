/// 其余板块种子内容模型
///
/// - [SeedReadingPassage] 阅读篇章（id 前缀 `p_`）
/// - [SeedSpeakingScenario] 口语场景骨架（id 前缀 `sc_`）
/// - [SeedCollocation] 写作动词搭配（id 前缀 `col_`）
/// - [SeedWritingPrompt] 写作题目（id 前缀 `wp_`）
///
/// 同族规范：只读静态内容、active 软下线、字段对齐 prompt.md 输出 schema，
/// 运行时 AI 生成的题目/标注不入库。
library;

import 'dart:convert';

List<String> _parseList(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    return (jsonDecode(json) as List).map((e) => e.toString()).toList();
  } catch (_) {
    return const [];
  }
}

// ══════════════════════════════════════════════════════════
// 阅读：seed_reading_passages
// ══════════════════════════════════════════════════════════

class SeedReadingPassage {
  const SeedReadingPassage({
    required this.id,
    required this.title,
    required this.passage,
    required this.cefr,
    this.difficulty = 3,
    this.wordCount,
    this.topicTags = const [],
    this.grammarTags = const [],
    this.source,
    this.active = true,
    required this.createdAt,
  });

  final String id; // 'p_flutter_state'
  final String title;
  final String passage; // 英文正文（80-200 词，prompt.md §四）
  final String cefr;
  final int difficulty;
  final int? wordCount;

  /// 主题标签 ['flutter', 'state_management']
  final List<String> topicTags;

  /// 文中刻意嵌入的语法结构（薄弱点回灌用）
  final List<String> grammarTags;

  /// 内容来源标记，如 'flutter_docs' / 'ai_generated'
  final String? source;
  final bool active;
  final DateTime createdAt;

  factory SeedReadingPassage.fromMap(Map<String, Object?> map) =>
      SeedReadingPassage(
        id: map['id']! as String,
        title: map['title']! as String,
        passage: map['passage']! as String,
        cefr: map['cefr']! as String,
        difficulty: (map['difficulty'] as int?) ?? 3,
        wordCount: map['word_count'] as int?,
        topicTags: _parseList(map['topic_tags_json'] as String?),
        grammarTags: _parseList(map['grammar_tags_json'] as String?),
        source: map['source'] as String?,
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at']! as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'passage': passage,
        'cefr': cefr,
        'difficulty': difficulty,
        'word_count': wordCount ?? passage.split(RegExp(r'\s+')).length,
        'topic_tags_json': topicTags.isEmpty ? null : jsonEncode(topicTags),
        'grammar_tags_json':
            grammarTags.isEmpty ? null : jsonEncode(grammarTags),
        'source': source,
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };
}

// ══════════════════════════════════════════════════════════
// 口语：seed_speaking_scenarios
// ══════════════════════════════════════════════════════════

class SeedSpeakingScenario {
  const SeedSpeakingScenario({
    required this.id,
    required this.scenarioType,
    required this.title,
    this.descriptionCn,
    this.userRoleCn,
    this.aiRoleCn,
    required this.cefr,
    this.difficulty = 3,
    this.keywords = const [],
    this.grammarTags = const [],
    this.active = true,
    required this.createdAt,
  });

  final String id; // 'sc_code_review'
  final String scenarioType; // 'standup' / 'code_review' / 'one_on_one'...
  final String title;
  final String? descriptionCn;
  final String? userRoleCn;
  final String? aiRoleCn;
  final String cefr;
  final int difficulty;

  /// 用户表达时的关键词（如 fixed / working on / no blockers）
  final List<String> keywords;

  /// 引导使用的语法点（f3 回灌用）
  final List<String> grammarTags;

  final bool active;
  final DateTime createdAt;

  factory SeedSpeakingScenario.fromMap(Map<String, Object?> map) =>
      SeedSpeakingScenario(
        id: map['id']! as String,
        scenarioType: map['scenario_type']! as String,
        title: map['title']! as String,
        descriptionCn: map['description_cn'] as String?,
        userRoleCn: map['user_role_cn'] as String?,
        aiRoleCn: map['ai_role_cn'] as String?,
        cefr: map['cefr']! as String,
        difficulty: (map['difficulty'] as int?) ?? 3,
        keywords: _parseList(map['keywords_json'] as String?),
        grammarTags: _parseList(map['grammar_tags_json'] as String?),
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at']! as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'scenario_type': scenarioType,
        'title': title,
        'description_cn': descriptionCn,
        'user_role_cn': userRoleCn,
        'ai_role_cn': aiRoleCn,
        'cefr': cefr,
        'difficulty': difficulty,
        'keywords_json': keywords.isEmpty ? null : jsonEncode(keywords),
        'grammar_tags_json':
            grammarTags.isEmpty ? null : jsonEncode(grammarTags),
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };
}

// ══════════════════════════════════════════════════════════
// 写作：seed_collocations / seed_writing_prompts
// ══════════════════════════════════════════════════════════

class SeedCollocation {
  const SeedCollocation({
    required this.id,
    required this.phrase,
    required this.meaningCn,
    this.example,
    this.exampleCn,
    required this.cefr,
    this.difficulty = 3,
    this.tags = const [],
    this.active = true,
    required this.createdAt,
  });

  final String id; // 'col_pick_up'
  final String phrase; // 'pick up (a ticket)'
  final String meaningCn;
  final String? example;
  final String? exampleCn;
  final String cefr;
  final int difficulty;
  final List<String> tags;
  final bool active;
  final DateTime createdAt;

  factory SeedCollocation.fromMap(Map<String, Object?> map) =>
      SeedCollocation(
        id: map['id']! as String,
        phrase: map['phrase']! as String,
        meaningCn: map['meaning_cn']! as String,
        example: map['example'] as String?,
        exampleCn: map['example_cn'] as String?,
        cefr: map['cefr']! as String,
        difficulty: (map['difficulty'] as int?) ?? 3,
        tags: _parseList(map['tags_json'] as String?),
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at']! as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'phrase': phrase,
        'meaning_cn': meaningCn,
        'example': example,
        'example_cn': exampleCn,
        'cefr': cefr,
        'difficulty': difficulty,
        'tags_json': tags.isEmpty ? null : jsonEncode(tags),
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };
}

class SeedWritingPrompt {
  const SeedWritingPrompt({
    required this.id,
    required this.promptCn,
    this.keywords = const [],
    this.theme,
    required this.cefr,
    this.difficulty = 3,
    this.tags = const [],
    this.active = true,
    required this.createdAt,
  });

  final String id; // 'wp_fix_bug'
  final String promptCn; // '描述你今天修的一个 bug'

  /// 提示词（debug, fix, deploy...，prompt.md §五 next_practice_prompt 风格）
  final List<String> keywords;
  final String? theme; // 练习主题
  final String cefr;
  final int difficulty;
  final List<String> tags;
  final bool active;
  final DateTime createdAt;

  factory SeedWritingPrompt.fromMap(Map<String, Object?> map) =>
      SeedWritingPrompt(
        id: map['id']! as String,
        promptCn: map['prompt_cn']! as String,
        keywords: _parseList(map['keywords_json'] as String?),
        theme: map['theme'] as String?,
        cefr: map['cefr']! as String,
        difficulty: (map['difficulty'] as int?) ?? 3,
        tags: _parseList(map['tags_json'] as String?),
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at']! as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'prompt_cn': promptCn,
        'keywords_json': keywords.isEmpty ? null : jsonEncode(keywords),
        'theme': theme,
        'cefr': cefr,
        'difficulty': difficulty,
        'tags_json': tags.isEmpty ? null : jsonEncode(tags),
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };
}
