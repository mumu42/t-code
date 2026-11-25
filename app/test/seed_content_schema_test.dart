import 'package:flutter_test/flutter_test.dart';
import 'package:linguaflow/data/schema.dart';
import 'package:linguaflow/models/seed_content.dart';
import 'package:linguaflow/models/seed_sentence.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('板块种子表 schema v4', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      for (final stmt in kSchemaStatements) {
        await db.execute(stmt);
      }
    });

    tearDown(() async => db.close());

    test('seed_sentences 建表 + 模型往返（含 audioHint / wordCount）', () async {
      final s = SeedSentence(
        id: 's_standup_001',
        text: "I'll pick up that ticket after standup.",
        translationCn: '站会结束后我会接那张任务卡。',
        cefr: 'A2',
        difficulty: 2,
        sourceType: 'listening',
        sourceRef: 'sc_standup',
        keywords: const ['pick up', 'ticket'],
        grammarTags: const ['tense:future'],
        audioHint: const {'rate': 0.9, 'pause_after_ms': 1500},
        createdAt: DateTime(2026, 1, 1),
      );
      await db.insert('seed_sentences', s.toMap());

      final loaded = SeedSentence.fromMap(
          (await db.query('seed_sentences')).first);
      expect(loaded.id, 's_standup_001');
      expect(loaded.keywords, ['pick up', 'ticket']);
      expect(loaded.grammarTags, ['tense:future']);
      expect(loaded.audioHint?['rate'], 0.9);
      expect(loaded.wordCount, 7);
      expect(loaded.active, isTrue);
    });

    test('seed_reading_passages 模型往返（topicTags / wordCount 自动计算）',
        () async {
      final p = SeedReadingPassage(
        id: 'p_flutter_state',
        title: 'State Management in Flutter',
        passage: 'When I first started using Flutter, I struggled with state.',
        cefr: 'B1',
        topicTags: const ['flutter', 'state_management'],
        grammarTags: const ['tense:past_simple'],
        source: 'flutter_docs',
        createdAt: DateTime(2026, 1, 1),
      );
      await db.insert('seed_reading_passages', p.toMap());

      final loaded = SeedReadingPassage.fromMap(
          (await db.query('seed_reading_passages')).first);
      expect(loaded.topicTags, ['flutter', 'state_management']);
      expect(loaded.source, 'flutter_docs');
      expect(loaded.wordCount, 10);
    });

    test('seed_speaking_scenarios 模型往返', () async {
      final sc = SeedSpeakingScenario(
        id: 'sc_code_review',
        scenarioType: 'code_review',
        title: 'Reply to a code review comment',
        descriptionCn: '同事在你的 PR 上留了修改意见，你需要回复。',
        userRoleCn: '你是 PR 作者，需要回应意见',
        aiRoleCn: '你是 reviewer，会追问细节',
        cefr: 'B1',
        keywords: const ['looks good', 'address', 'follow up'],
        grammarTags: const ['modal:can_could'],
        createdAt: DateTime(2026, 1, 1),
      );
      await db.insert('seed_speaking_scenarios', sc.toMap());

      final loaded = SeedSpeakingScenario.fromMap(
          (await db.query('seed_speaking_scenarios')).first);
      expect(loaded.scenarioType, 'code_review');
      expect(loaded.keywords, hasLength(3));
      expect(loaded.aiRoleCn, isNotNull);
    });

    test('seed_collocations 模型往返 + phrase 唯一约束', () async {
      final c = SeedCollocation(
        id: 'col_pick_up',
        phrase: 'pick up (a ticket)',
        meaningCn: '认领、接手（一张任务卡）',
        example: "I'll pick up that ticket tomorrow.",
        cefr: 'B1',
        tags: const ['workplace'],
        createdAt: DateTime(2026, 1, 1),
      );
      await db.insert('seed_collocations', c.toMap());

      final loaded = SeedCollocation.fromMap(
          (await db.query('seed_collocations')).first);
      expect(loaded.phrase, 'pick up (a ticket)');
      expect(loaded.tags, ['workplace']);

      // 同 phrase 不同 id → 唯一约束拒绝
      final dup = SeedCollocation(
        id: 'col_pick_up_2',
        phrase: 'pick up (a ticket)',
        meaningCn: '重复条目',
        cefr: 'B1',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(() => db.insert('seed_collocations', dup.toMap()),
          throwsA(isA<Exception>()));
    });

    test('seed_writing_prompts 模型往返', () async {
      final wp = SeedWritingPrompt(
        id: 'wp_fix_bug',
        promptCn: '描述你今天修的一个 bug：现象、原因、解法。',
        keywords: const ['debug', 'fix', 'deploy', 'root cause'],
        theme: 'daily_work',
        cefr: 'B1',
        tags: const ['tech'],
        createdAt: DateTime(2026, 1, 1),
      );
      await db.insert('seed_writing_prompts', wp.toMap());

      final loaded = SeedWritingPrompt.fromMap(
          (await db.query('seed_writing_prompts')).first);
      expect(loaded.promptCn, contains('bug'));
      expect(loaded.keywords, hasLength(4));
      expect(loaded.theme, 'daily_work');
    });

    test('五表 DDL 幂等重放（模拟 v4 升级路径）', () async {
      await db.insert(
          'seed_sentences',
          SeedSentence(
                  id: 's_x',
                  text: 'hello',
                  cefr: 'A1',
                  sourceType: 'listening',
                  createdAt: DateTime(2026, 1, 1))
              .toMap());
      for (final stmt in kSchemaStatements) {
        await db.execute(stmt);
      }
      expect(await db.query('seed_sentences'), hasLength(1));
      // v4 五表全部存在
      final tables = (await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table'"))
          .map((r) => r['name'])
          .toSet();
      for (final t in [
        'seed_sentences',
        'seed_reading_passages',
        'seed_speaking_scenarios',
        'seed_collocations',
        'seed_writing_prompts'
      ]) {
        expect(tables, contains(t));
      }
    });
  });
}
