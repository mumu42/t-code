/// 种子句模型 — seed_sentences 表（听力/阅读/口语三板块共用）
///
/// f4 §6：听力精听句、阅读硬句、口语跟读句的 SRS item_id 均指向本表。
/// id 前缀 `s_`（如 's_standup_001'）。
library;

import 'dart:convert';

class SeedSentence {
  const SeedSentence({
    required this.id,
    required this.text,
    this.translationCn,
    required this.cefr,
    this.difficulty = 3,
    this.wordCount,
    required this.sourceType,
    this.sourceRef,
    this.keywords = const [],
    this.grammarTags = const [],
    this.audioHint,
    this.active = true,
    required this.createdAt,
  });

  final String id;
  final String text;
  final String? translationCn;
  final String cefr;
  final int difficulty;

  /// 'listening'（精听句）/ 'reading'（硬句）/ 'speaking'（跟读句）
  final String sourceType;

  /// 所属篇章/场景 id（可空，独立句子无来源）
  final String? sourceRef;

  /// 听力关键词（2-3 个/句）
  final List<String> keywords;

  /// 该句考察的语法点（'tense:past_simple' 等）
  final List<String> grammarTags;

  /// f2 §八：音频提示（{'rate': 0.9, 'pause_after_ms': 1500}）
  final Map<String, Object?>? audioHint;

  final int? wordCount;
  final bool active;
  final DateTime createdAt;

  static List<String> _parseList(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      return (jsonDecode(json) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  factory SeedSentence.fromMap(Map<String, Object?> map) => SeedSentence(
        id: map['id']! as String,
        text: map['text']! as String,
        translationCn: map['translation_cn'] as String?,
        cefr: map['cefr']! as String,
        difficulty: (map['difficulty'] as int?) ?? 3,
        wordCount: map['word_count'] as int?,
        sourceType: map['source_type']! as String,
        sourceRef: map['source_ref'] as String?,
        keywords: _parseList(map['keywords_json'] as String?),
        grammarTags: _parseList(map['grammar_tags_json'] as String?),
        audioHint: _parseAudioHint(map['audio_hint_json'] as String?),
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at']! as String),
      );

  static Map<String, Object?>? _parseAudioHint(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return (jsonDecode(json) as Map).cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'text': text,
        'translation_cn': translationCn,
        'cefr': cefr,
        'difficulty': difficulty,
        'word_count': wordCount ?? text.split(RegExp(r'\s+')).length,
        'source_type': sourceType,
        'source_ref': sourceRef,
        'keywords_json': keywords.isEmpty ? null : jsonEncode(keywords),
        'grammar_tags_json':
            grammarTags.isEmpty ? null : jsonEncode(grammarTags),
        'audio_hint_json': audioHint == null ? null : jsonEncode(audioHint),
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };
}
