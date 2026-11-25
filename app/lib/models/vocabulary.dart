/// 词汇内容模型 — seed_words 与 vocab_cards（两表字段同构）
///
/// - [SeedWord]：内置词库行（id 前缀 `w_`，随版本发布，只读）
/// - [VocabCard]：用户/AI 词卡行（id 前缀 `uv_`，运行时产生）
///
/// 复习页翻卡组件对两者无感：字段一一对应，用 [VocabEntry] 统一消费。
/// 字段与 prompt.md §一输出 schema 对齐（AI 生成词卡直接落 VocabCard）。
library;

import 'dart:convert';

/// 两表共有的同构字段（SeedWord / VocabCard 共同实现，
/// VocabEntry 统一消费时无需关心来源）
abstract interface class VocabWordData {
  String get id;
  String get word;
  String? get phonetics;
  String? get partOfSpeech;
  String get meaningCn;
  String? get example;
  String? get exampleCn;
  String get cefr;
  int get difficulty;
  List<String> get tags;
  List<String> get grammarTags;
}

class SeedWord implements VocabWordData {
  const SeedWord({
    required this.id,
    required this.word,
    this.phonetics,
    this.partOfSpeech,
    required this.meaningCn,
    this.example,
    this.exampleCn,
    required this.cefr,
    this.difficulty = 3,
    this.tags = const [],
    this.grammarTags = const [],
    this.active = true,
    required this.createdAt,
  });

  @override
  final String id; // 'w_refactor'
  @override
  final String word;
  @override
  final String? phonetics;
  @override
  final String? partOfSpeech;
  @override
  final String meaningCn;
  @override
  final String? example;
  @override
  final String? exampleCn;
  @override
  final String cefr;
  @override
  final int difficulty; // 1-5
  @override
  final List<String> tags; // tech/frontend/workplace...
  @override
  final List<String> grammarTags; // 'tense:past_simple' 等
  final bool active; // 软下线标记，false 时抽取/复习均跳过
  final DateTime createdAt;

  static List<String> _parseTags(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  factory SeedWord.fromMap(Map<String, Object?> map) => SeedWord(
        id: map['id']! as String,
        word: map['word']! as String,
        phonetics: map['phonetics'] as String?,
        partOfSpeech: map['part_of_speech'] as String?,
        meaningCn: map['meaning_cn']! as String,
        example: map['example'] as String?,
        exampleCn: map['example_cn'] as String?,
        cefr: map['cefr']! as String,
        difficulty: (map['difficulty'] as int?) ?? 3,
        tags: _parseTags(map['tags_json'] as String?),
        grammarTags: _parseTags(map['grammar_tags_json'] as String?),
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at']! as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'word': word,
        'phonetics': phonetics,
        'part_of_speech': partOfSpeech,
        'meaning_cn': meaningCn,
        'example': example,
        'example_cn': exampleCn,
        'cefr': cefr,
        'difficulty': difficulty,
        'tags_json': jsonEncode(tags),
        'grammar_tags_json':
            grammarTags.isEmpty ? null : jsonEncode(grammarTags),
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };
}

class VocabCard implements VocabWordData {
  const VocabCard({
    required this.id,
    required this.userId,
    required this.word,
    this.phonetics,
    this.partOfSpeech,
    required this.meaningCn,
    this.example,
    this.exampleCn,
    required this.cefr,
    this.difficulty = 3,
    this.tags = const [],
    this.grammarTags = const [],
    this.source = 'ai',
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final String id; // 'uv_xxx'
  final String userId;
  @override
  final String word;

  /// 'ai' = prompt.md 生成的词卡；'user' = 自建卡组；'pdf_import' = 词书导入
  final String source;
  @override
  final String? phonetics;
  @override
  final String? partOfSpeech;
  @override
  final String meaningCn;
  @override
  final String? example;
  @override
  final String? exampleCn;
  @override
  final String cefr;
  @override
  final int difficulty;
  @override
  final List<String> tags;
  @override
  final List<String> grammarTags;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory VocabCard.fromMap(Map<String, Object?> map) => VocabCard(
        id: map['id']! as String,
        userId: map['user_id']! as String,
        word: map['word']! as String,
        phonetics: map['phonetics'] as String?,
        partOfSpeech: map['part_of_speech'] as String?,
        meaningCn: map['meaning_cn']! as String,
        example: map['example'] as String?,
        exampleCn: map['example_cn'] as String?,
        cefr: map['cefr']! as String,
        difficulty: (map['difficulty'] as int?) ?? 3,
        tags: SeedWord._parseTags(map['tags_json'] as String?),
        grammarTags: SeedWord._parseTags(map['grammar_tags_json'] as String?),
        source: (map['source'] as String?) ?? 'ai',
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at']! as String),
        updatedAt: DateTime.parse(map['updated_at']! as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'word': word,
        'phonetics': phonetics,
        'part_of_speech': partOfSpeech,
        'meaning_cn': meaningCn,
        'example': example,
        'example_cn': exampleCn,
        'cefr': cefr,
        'difficulty': difficulty,
        'tags_json': jsonEncode(tags),
        'grammar_tags_json':
            grammarTags.isEmpty ? null : jsonEncode(grammarTags),
        'source': source,
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// 复习页/词汇板块统一消费的词条（SeedWord 或 VocabCard 的联合）
class VocabEntry implements VocabWordData {
  const VocabEntry._(this.seedWord, this.vocabCard);

  final SeedWord? seedWord;
  final VocabCard? vocabCard;

  factory VocabEntry.fromSeed(SeedWord w) => VocabEntry._(w, null);
  factory VocabEntry.fromCard(VocabCard c) => VocabEntry._(null, c);

  bool get isSeed => seedWord != null;

  /// 统一字段访问（两表同构）
  VocabWordData get _data => seedWord ?? vocabCard!;
  @override
  String get id => _data.id;
  @override
  String get word => _data.word;
  @override
  String? get phonetics => _data.phonetics;
  @override
  String? get partOfSpeech => _data.partOfSpeech;
  @override
  String get meaningCn => _data.meaningCn;
  @override
  String? get example => _data.example;
  @override
  String? get exampleCn => _data.exampleCn;
  @override
  String get cefr => _data.cefr;
  @override
  int get difficulty => _data.difficulty;
  @override
  List<String> get tags => _data.tags;
  @override
  List<String> get grammarTags => _data.grammarTags;
}
